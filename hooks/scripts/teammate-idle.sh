#!/usr/bin/env bash
# TeammateIdle hook for swarm plugin
#
# Nudges swarm specialists who go idle without having completed their
# task. Only fires for teammates in swarm-* teams.
# Pattern-aware: routes to appropriate gate logic per pattern.
#
# Input (stdin JSON): session_id, teammate_name, team_name, transcript_path
# Exit 0: allow idle (teammate may proceed to idle)
# Exit 2: block idle, stderr is sent as feedback to keep teammate working

set -euo pipefail

# Fail open if jq is not installed — warn so users know gates are inactive
if ! command -v jq >/dev/null 2>&1; then
  echo "swarm: jq not found — quality gates disabled (install jq to enable)" >&2
  exit 0
fi

INPUT=$(cat)

TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // empty')
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

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
if [[ "$TEAMMATE_NAME" == "monitor" ]]; then
  exit 0
fi

case "$PATTERN" in
  fan-out|swarm|map-reduce)
    # All agents must report findings via SendMessage
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
