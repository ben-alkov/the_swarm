<!-- markdownlint-disable link-image-style -->

# the_swarm

Claude Code plugin for multi-pattern multi-agent orchestration, using CC's built
in Agent Swarm as the engine — dispatches and coordinates specialist sub-agents
in fan-out, pipeline, map-reduce, speculative, and swarm configurations. Built
with Markdown, YAML, Bash, and JSON.

## Structure

- `skills/` - orchestration pattern skill definitions (one subdir per pattern)
- `config/` - role definitions, presets, and usage examples (`swarm-roles.yaml`)
- `hooks/` - quality-gate shell scripts for TeammateIdle/TaskCompleted events
- `.claude-plugin/` - plugin identity and marketplace metadata

## Key Files

- Plugin manifest: `.claude-plugin/plugin.json`
- Role and preset definitions: `config/swarm-roles.yaml`
- Dispatcher entry point: `skills/swarm/SKILL.md`
- Hook event bindings: `hooks/hooks.json`
- Pattern extraction: `hooks/scripts/lib/pattern-detect.sh`
- Usage examples: `config/examples/`

## CI Commands

```bash
jsonlint inputfile.json  # https://github.com/dmeranda/demjson
markdownlint-cli2 **/*.md  # https://github.com/DavidAnson/markdownlint-cli2
shellcheck hooks/scripts/**/*.sh  # https://www.shellcheck.net
yamllint config/  # https://github.com/adrienverge/yamllint
```

## Critical Context

- Entirely prompt-driven — no compiled code, no build step, no test framework
- Runtime deps: `bash` and `jq`
- Team name format encodes pattern: `swarm-{pattern}-{goal}-{ts}`
- Hook scripts use `set -euo pipefail`

## More Info

See [BOOKMARKS.md](BOOKMARKS.md) for architecture docs and usage examples.
