#!/usr/bin/env bash
# Shared pattern detection for swarm hooks
# Sources into calling scripts — sets $PATTERN variable
#
# Extracts pattern from team name convention:
#   swarm-{pattern}-{goal}-{ts}
# Falls back to "fan-out" for v1 team names without pattern segment.

# Guard against direct execution — this file must be sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: pattern-detect.sh must be sourced, not executed directly" >&2
  exit 1
fi

PATTERN_RE='^swarm-(fan-out|swarm|pipeline|task-graph'
PATTERN_RE+='|map-reduce|speculative)-'
# shellcheck disable=SC2034  # PATTERN is used by sourcing scripts
if [[ "$TEAM_NAME" =~ $PATTERN_RE ]]; then
  PATTERN="${BASH_REMATCH[1]}"
else
  PATTERN="fan-out"
fi
