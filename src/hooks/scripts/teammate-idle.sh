#!/usr/bin/env bash
# TeammateIdle hook for swarm plugin
#
# Nudges swarm specialists who go idle without having completed their
# task. Only fires for teammates in swarm-* teams.
# Pattern-aware: routes to appropriate gate logic per pattern.
#
# Input (stdin JSON): session_id, teammate_name, team_name, transcript_path,
#                     agent_id, agent_type
# Exit 0: allow idle (teammate may proceed to idle)
# Exit 2: block idle, stderr is sent as feedback to keep teammate working

set -euo pipefail

# Fail open if jq is not installed — warn so users know gates are inactive
if ! command -v jq >/dev/null 2>&1; then
  echo "swarm: jq not found — quality gates disabled (install jq to enable)" >&2
  exit 0
fi

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // empty')
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')

# Resolve the teammate's own transcript.
# TeammateIdle provides transcript_path as the *parent* session's transcript,
# not the teammate's. The teammate's transcript lives in the subagents/
# subdirectory of the parent session, named agent-{session_id}.jsonl.
if [[ -n "$TRANSCRIPT_PATH" ]]; then
  PARENT_DIR=$(dirname "$TRANSCRIPT_PATH")
  if [[ -n "$AGENT_ID" ]]; then
    AGENT_TRANSCRIPT="${PARENT_DIR}/subagents/agent-${AGENT_ID}.jsonl"
    if [[ -f "$AGENT_TRANSCRIPT" ]]; then
      TRANSCRIPT_PATH="$AGENT_TRANSCRIPT"
    fi
  elif [[ -n "$SESSION_ID" ]]; then
    AGENT_TRANSCRIPT="${PARENT_DIR}/subagents/agent-${SESSION_ID}.jsonl"
    if [[ -f "$AGENT_TRANSCRIPT" ]]; then
      TRANSCRIPT_PATH="$AGENT_TRANSCRIPT"
    fi
  fi
fi

# Only apply to swarm teams
if [[ -z "$TEAM_NAME" || ! "$TEAM_NAME" =~ ^swarm- ]]; then
  exit 0
fi

# Detect pattern from team name
source "$(dirname "$0")/lib/pattern-detect.sh"

# Fail open if transcript is unavailable — cannot verify, should not block
if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# Monitor agents are exempt from quality gates — they observe, not produce
if [[ "$AGENT_TYPE" == "monitor" || "$TEAMMATE_NAME" == "monitor" ]]; then
  exit 0
fi

case "$PATTERN" in
  fan-out|swarm|map-reduce)
    # Heuristic: matches tool calls in transcript JSON. May false-positive
    # on text that mentions SendMessage without actually calling it.
    if grep -qE '"name"\s*:\s*"SendMessage"' "$TRANSCRIPT_PATH" 2>/dev/null; then
      exit 0
    fi
    echo "$TEAMMATE_NAME: You haven't sent your findings to the team lead yet. Review the target, compile your analysis, and send your findings via SendMessage before stopping." >&2
    exit 2
    ;;
  pipeline|task-graph)
    # Stage agents: allow idle after SendMessage OR after committing
    if grep -qE '"name"\s*:\s*"SendMessage"|"git commit"' \
        "$TRANSCRIPT_PATH" 2>/dev/null; then
      exit 0
    fi
    echo "$TEAMMATE_NAME: You haven't sent findings or committed changes yet." >&2
    exit 2
    ;;
  speculative)
    # Approach agents must commit; judge must SendMessage
    if [[ "$TEAMMATE_NAME" == judge ]]; then
      if grep -qE '"name"\s*:\s*"SendMessage"' "$TRANSCRIPT_PATH" 2>/dev/null; then
        exit 0
      fi
      echo "$TEAMMATE_NAME: You haven't sent your verdict to the team lead yet." >&2
      exit 2
    else
      # Approach agents (approach-1, approach-2, etc.)
      if grep -q '"git commit"' "$TRANSCRIPT_PATH" 2>/dev/null; then
        exit 0
      fi
      echo "$TEAMMATE_NAME: You haven't committed your approach yet." >&2
      exit 2
    fi
    ;;
  *)
    exit 0
    ;;
esac
