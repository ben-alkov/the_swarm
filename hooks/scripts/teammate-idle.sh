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

case "$PATTERN" in
  fan-out|swarm|map-reduce)
    # All agents must report findings via SendMessage
    if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
      if grep -q '"SendMessage"' "$TRANSCRIPT_PATH" 2>/dev/null; then
        exit 0
      fi
    fi
    echo "You haven't sent your findings to the team lead yet. Review the target, compile your analysis, and send your findings via SendMessage before stopping." >&2
    exit 2
    ;;
  pipeline|task-graph)
    # Stage agents: allow idle after SendMessage OR after committing
    if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
      if grep -q '"SendMessage"\|"git commit"' \
          "$TRANSCRIPT_PATH" 2>/dev/null; then
        exit 0
      fi
    fi
    echo "You haven't sent findings or committed changes yet." >&2
    exit 2
    ;;
  speculative)
    # Approach agents: must commit; judge: must SendMessage
    if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
      if grep -q '"SendMessage"\|"git commit"' \
          "$TRANSCRIPT_PATH" 2>/dev/null; then
        exit 0
      fi
    fi
    echo "You haven't committed your approach or sent a verdict." >&2
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
