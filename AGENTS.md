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

## CI Commands

```bash
jsonlint src/hooks/hooks.json  # https://github.com/dmeranda/demjson
markdownlint-cli2 **/*.md  # https://github.com/DavidAnson/markdownlint-cli2
shellcheck hooks/scripts/**/*.sh  # https://www.shellcheck.net
yamllint config/swarm-roles.yaml  # https://github.com/adrienverge/yamllint
```

These are examples; use other invocations if needed.

## Critical Context

- Entirely prompt-driven — no compiled code, no build step, no test framework
- Runtime deps: `bash` and `jq`
- Team name format encodes pattern: `swarm-{pattern}-{goal}-{ts}`
- Hook scripts use `set -euo pipefail`

## More Info

See [BOOKMARKS.md](BOOKMARKS.md) for architecture docs and usage examples.
