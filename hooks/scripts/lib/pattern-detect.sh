#!/usr/bin/env bash
# Shared pattern detection for swarm hooks
# Sources into calling scripts — sets $PATTERN variable
#
# Extracts pattern from team name convention:
#   swarm-{pattern}-{goal}-{ts}
# Falls back to "fan-out" for v1 team names without pattern segment.

PATTERN_RE='^swarm-(fan-out|swarm|pipeline|task-graph'
PATTERN_RE+='|map-reduce|speculative)-'
if [[ "$TEAM_NAME" =~ $PATTERN_RE ]]; then
  PATTERN="${BASH_REMATCH[1]}"
else
  PATTERN="fan-out"
fi
