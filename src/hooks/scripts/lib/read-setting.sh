#!/usr/bin/env bash
# Shared settings reader for swarm hooks
# Sources into calling scripts — provides read_setting()
#
# Reads a value from ${CLAUDE_PLUGIN_ROOT}/.claude-plugin/settings.json,
# falling back to a caller-supplied default when the key is absent or jq
# is unavailable.

set -euo pipefail

# Guard against direct execution — this file must be sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: read-setting.sh must be sourced, not executed directly" >&2
  exit 1
fi

read_setting() {
  local key="$1" default="$2"
  local settings="${CLAUDE_PLUGIN_ROOT}/.claude-plugin/settings.json"
  if [[ -f "$settings" ]] && command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$key" --arg d "$default" '.[$k] // $d' "$settings" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}
