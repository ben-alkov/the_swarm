<!-- markdownlint-disable link-image-style line-length -->

# the_swarm

Claude Code plugin for multi-pattern multi-agent orchestration, using CC's built
in Agent Swarm as the engine — dispatches and coordinates specialist sub-agents
in fan-out, pipeline, map-reduce, speculative, and swarm configurations. Built
with Markdown, YAML, Bash, and JSON.

## Structure

- `src/skills/` - orchestration pattern skill definitions (one subdir per pattern)
- `src/config/` - role definitions, presets, and usage examples (`swarm-roles.yaml`)
- `src/hooks/` - quality-gate shell scripts for TeammateIdle/TaskCompleted events
- `src/.claude-plugin/` - plugin identity and metadata

## Key Files

- Plugin manifest: `src/.claude-plugin/plugin.json`
- Role and preset definitions: `src/config/swarm-roles.yaml`
- Dispatcher entry point: `src/skills/swarm/SKILL.md`
- Hook event bindings: `src/hooks/hooks.json`
- Pattern extraction: `src/hooks/scripts/lib/pattern-detect.sh`
- Read from user settings: `src/hooks/scripts/lib/read-setting.sh`
- Usage examples: `src/config/examples/`

## CI

This repo has GitHub Actions for CI; see below for instructions for running
actions locally using [`act`][].

## Directly run linters

  ```bash
  jq src/hooks/hooks.json 2>&1 >/dev/null  # If jq can't parse the file, it's invalid
  markdownlint-cli2 src/{,**/}*.md  # https://github.com/DavidAnson/markdownlint-cli2
  shellcheck -x src/hooks/scripts/**/*.sh  # https://github.com/koalaman/shellcheck
  yq --exit-status 'tag == "!!map" or tag == "!!seq"' src/config/*.yaml >/dev/null  # https://github.com/mikefarah/yq
  yamlfmt -lint src/config/  # https://github.com/google/yamlfmt
  yamlfmt src/config/  # format in place (local only, not in CI)
  ```

  N.B. These are examples; use other invocations if needed.

## Or check for `gh act`, install it if missing

  `gh extension install https://github.com/nektos/gh-act`

  and use it to run the actual GitHub Action jobs

  e.g. `gh act --job "yaml"`

  Use `gh act -l` to discover the available job IDs.

## Critical Context

- Entirely prompt-driven — no compiled code, no build step, no test framework
- Runtime deps: `bash` and `jq`
- Team name format encodes pattern: `swarm-{pattern}-{goal}-{ts}`
- Hook scripts use `set -euo pipefail`

## More Info

See [BOOKMARKS.md](BOOKMARKS.md) for architecture docs and usage examples.

[`act`]: https://github.com/nektos/act
