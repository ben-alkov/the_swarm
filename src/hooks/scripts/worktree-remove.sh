#!/usr/bin/env bash
# WorktreeRemove hook for swarm plugin
#
# Cleans up escalation counter files when agent worktrees are removed.
# Only acts on swarm-* worktrees; exits cleanly for everything else.
#
# Input (stdin JSON): session_id, transcript_path, cwd,
#                     hook_event_name, worktree_path
# Exit 0: always (cleanup is best-effort)

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat)
WORKTREE_PATH=$(echo "$INPUT" | jq -r '.worktree_path // empty')

if [[ -z "$WORKTREE_PATH" ]]; then
  exit 0
fi

# Derive worktree name from path
WORKTREE_NAME=$(basename "$WORKTREE_PATH")

# Only clean up swarm-related worktrees
if [[ ! "$WORKTREE_NAME" =~ ^swarm- ]]; then
  exit 0
fi

# Clean up escalation counter files for this team
COUNTER_DIR="${HOME}/temp/swarm-idle-counters"
if [[ -d "$COUNTER_DIR" ]]; then
  rm -f "${COUNTER_DIR}/swarm-idle-${WORKTREE_NAME}-"*.count
fi

exit 0
