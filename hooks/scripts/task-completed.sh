#!/usr/bin/env bash
# TaskCompleted hook for swarm plugin
#
# Validates that specialist tasks have substantive findings before
# allowing completion. Only fires for tasks in swarm-* teams.
# Pattern-aware: routes to appropriate gate logic per pattern.
#
# Input (stdin JSON): task_id, task_subject, task_description,
#                     teammate_name, team_name, transcript_path
# Exit 0: allow completion
# Exit 2: block completion, stderr is sent as feedback

set -euo pipefail

# Fail open if jq is not installed — silent bypass is worse than no gate
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)

TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // empty')
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // empty')
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // empty')
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
    # All agents must send findings via SendMessage before completing
    if grep -qE '"name"\s*:\s*"SendMessage"' "$TRANSCRIPT_PATH" 2>/dev/null; then
      exit 0
    fi
    echo "$TEAMMATE_NAME: Task '$TASK_SUBJECT' cannot be completed until you send your findings to the team lead via SendMessage." >&2
    exit 2
    ;;
  pipeline|task-graph)
    # Stage agents: allow completion after SendMessage OR after committing
    if grep -qE '"name"\s*:\s*"SendMessage"|"git commit"' \
        "$TRANSCRIPT_PATH" 2>/dev/null; then
      exit 0
    fi
    echo "$TEAMMATE_NAME: Task '$TASK_SUBJECT' cannot be completed until you send findings or commit changes." >&2
    exit 2
    ;;
  speculative)
    # Approach agents must commit; judge must SendMessage
    if [[ "$TEAMMATE_NAME" == judge ]]; then
      if grep -qE '"name"\s*:\s*"SendMessage"' "$TRANSCRIPT_PATH" 2>/dev/null; then
        exit 0
      fi
      echo "$TEAMMATE_NAME: Task '$TASK_SUBJECT' cannot be completed until you send your verdict." >&2
      exit 2
    else
      if grep -q '"git commit"' "$TRANSCRIPT_PATH" 2>/dev/null; then
        exit 0
      fi
      echo "$TEAMMATE_NAME: Task '$TASK_SUBJECT' cannot be completed until you commit your approach." >&2
      exit 2
    fi
    ;;
  *)
    exit 0
    ;;
esac
