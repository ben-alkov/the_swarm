#!/usr/bin/env bash
# TeammateIdle hook for swarm plugin
#
# Nudges swarm specialists who go idle without having completed their
# task. Only fires for teammates in swarm-* teams.
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

# Check if the teammate has sent a SendMessage in their transcript
# (indicating they reported findings to the lead)
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  # Look for SendMessage tool calls in the transcript
  if grep -q '"SendMessage"' "$TRANSCRIPT_PATH" 2>/dev/null; then
    # Teammate has sent at least one message — allow idle
    exit 0
  fi
fi

# Teammate is going idle without having sent findings
echo "You haven't sent your findings to the team lead yet. Review the target, compile your analysis, and send your findings via SendMessage before stopping." >&2
exit 2
