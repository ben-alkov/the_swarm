#!/usr/bin/env bash
# TaskCompleted hook for swarm plugin
#
# Validates that specialist tasks have substantive findings before
# allowing completion. Only fires for tasks in swarm-* teams.
#
# Input (stdin JSON): task_id, task_subject, task_description,
#                     teammate_name, team_name, transcript_path
# Exit 0: allow completion
# Exit 2: block completion, stderr is sent as feedback

set -euo pipefail

INPUT=$(cat)

TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // empty')
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // empty')
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# Only apply to swarm teams
if [[ -z "$TEAM_NAME" || ! "$TEAM_NAME" =~ ^swarm- ]]; then
  exit 0
fi

# Verify the teammate sent findings via SendMessage before completing
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  if grep -q '"SendMessage"' "$TRANSCRIPT_PATH" 2>/dev/null; then
    exit 0
  fi
fi

# Task being marked complete without sending findings
echo "Task '$TASK_SUBJECT' cannot be completed until you send your findings to the team lead via SendMessage. Compile your analysis and send it before marking this task complete." >&2
exit 2
