#!/usr/bin/env bash
# TaskCompleted hook for swarm plugin
#
# Validates that specialist tasks have substantive findings before
# allowing completion. Only fires for tasks in swarm-* teams.
# Pattern-aware: routes to appropriate gate logic per pattern.
#
# Input (stdin JSON): task_id, task_subject, task_description,
#                     teammate_name, team_name, transcript_path,
#                     agent_id, agent_type
# Exit 0: allow completion
# Exit 0 + JSON {"continue": false}: hard-stop after repeated nudges
# Exit 2: block completion, stderr is sent as feedback

set -euo pipefail

# Fail open if jq is not installed — warn so users know gates are inactive
if ! command -v jq >/dev/null 2>&1; then
  echo "swarm: jq not found — quality gates disabled (install jq to enable)" >&2
  exit 0
fi

INPUT=$(cat)

TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // empty')
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // empty')
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
# shellcheck disable=SC2034  # reserved for future transcript path resolution
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')

# Only apply to swarm teams
if [[ -z "$TEAM_NAME" || ! "$TEAM_NAME" =~ ^swarm- ]]; then
  exit 0
fi

# Detect pattern from team name
source "$(dirname "$0")/lib/pattern-detect.sh"
source "$(dirname "$0")/lib/read-setting.sh"

# Escalation: stop teammates after repeated nudges without progress
IDLE_THRESHOLD=$(read_setting "idle_escalation_threshold" "3")
COUNTER_DIR="${HOME}/temp/swarm-idle-counters"
mkdir -p "$COUNTER_DIR"

# Nudge (exit 2) or hard-stop (exit 0 + JSON) based on cycle count.
# Uses jq for JSON construction to avoid injection from teammate names.
nudge_or_stop() {
  local message="$1"
  local counter_file="${COUNTER_DIR}/swarm-idle-${TEAM_NAME}-${TEAMMATE_NAME}.count"
  local count=0
  if [[ -f "$counter_file" ]]; then
    count=$(< "$counter_file")
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
  fi
  count=$((count + 1))
  echo "$count" > "$counter_file"
  if [[ "$count" -ge "$IDLE_THRESHOLD" ]]; then
    rm -f "$counter_file"
    jq -n --arg name "$TEAMMATE_NAME" --argjson count "$count" \
      '{"continue": false, "stopReason": ($name + " stopped after " + ($count|tostring) + " idle cycles without expected output")}'
    exit 0
  fi
  echo "$message" >&2
  exit 2
}

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
    nudge_or_stop "$TEAMMATE_NAME: Task '$TASK_SUBJECT' cannot be completed until you send your findings to the team lead via SendMessage."
    ;;
  pipeline|task-graph)
    # Stage agents: allow completion after SendMessage OR after committing
    if grep -qE '"name"\s*:\s*"SendMessage"|"git commit"' \
        "$TRANSCRIPT_PATH" 2>/dev/null; then
      exit 0
    fi
    nudge_or_stop "$TEAMMATE_NAME: Task '$TASK_SUBJECT' cannot be completed until you send findings or commit changes."
    ;;
  speculative)
    # Approach agents must commit; judge must SendMessage
    if [[ "$TEAMMATE_NAME" == judge ]]; then
      if grep -qE '"name"\s*:\s*"SendMessage"' "$TRANSCRIPT_PATH" 2>/dev/null; then
        exit 0
      fi
      nudge_or_stop "$TEAMMATE_NAME: Task '$TASK_SUBJECT' cannot be completed until you send your verdict."
    else
      if grep -q '"git commit"' "$TRANSCRIPT_PATH" 2>/dev/null; then
        exit 0
      fi
      nudge_or_stop "$TEAMMATE_NAME: Task '$TASK_SUBJECT' cannot be completed until you commit your approach."
    fi
    ;;
  *)
    exit 0
    ;;
esac
