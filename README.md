# the_swarm

A Claude Code plugin which orchestrates multiple agents in parallel. Define
specialist roles, pick a pattern, and let the swarm work concurrently — review
code from three angles at once, race competing implementations, or pipeline
stages with dependency gates.

## Requirements

- [Claude Code][] v2.1.49+
- `bash`, `jq`

## Installation

```bash
claude plugin marketplace add ben-alkov/the_swarm
claude plugin install the_swarm
```

## Quick Start

```text
> /swarm review this PR with the pr-review preset
```

Claude reads the preset, spawns three specialists (security, performance,
quality), collects their findings, and synthesizes a unified report — all in
one command.

Presets, specialists, and even orchestration patterns (see below) are fully
customizable, extensible, and composable (although the orchestration patterns
generically cover a very large space).

Want reviewer team members which are more tailored to your repo/stack/language?
Tweak the `prompt` fields in `config/swarm-roles.yaml`

Not even working on source code per se, but still want to use the_swarm? Create
your own roles!

## Orchestration Patterns

### Fan-Out

Parallel specialists analyze the same target independently. Each specialist
has a distinct focus; the lead merges their findings into one report.

```text
> /swarm review src/auth/ with pr-review preset
```

**Built-in presets:** `pr-review`, `full-review`, `security-audit`

### Pipeline

Sequential stages where each stage blocks the next. An implementer writes
code in a worktree; reviewers evaluate the result only after implementation
completes.

```text
> /swarm implement and review with implement-then-review preset
```

### Task Graph

An arbitrary DAG of stages with `depends_on` edges. Supports fan-in (multiple
predecessors gate a single successor) and fan-out (one predecessor unblocks
several successors).

```text
> /swarm migrate the database with multi-stage-migration preset
```

### Map-Reduce

Split a large input into chunks, process each chunk in parallel, then merge
all outputs. Mappers analyze independent partitions; a reducer teammate
produces the unified result.

```text
> /swarm audit the codebase with large-codebase-audit preset
```

### Speculative

Race competing implementations in isolated worktrees. A judge evaluates all
approaches — runs tests, checks quality — and selects the winner.

```text
> /swarm refactor auth with best-of-three preset
```

### Swarm (Self-Claiming Pool)

Interchangeable workers claim tasks from a shared pool and loop until the pool
empties. Unlike fan-out, the task pool can be larger than the worker count.

```text
> /swarm audit all modules with swarm-module-audit preset
```

## Roles and Presets

Roles define what each agent does. Presets bundle roles into ready-made
configurations for common workflows.

### Built-in Roles

| Role                    | Purpose                                   | Access     |
|-------------------------|-------------------------------------------|------------|
| `security-reviewer`     | Vulnerability analysis                    | Read-only  |
| `performance-reviewer`  | Performance bottlenecks                   | Read-only  |
| `quality-reviewer`      | Code quality and maintainability          | Read-only  |
| `architecture-reviewer` | Architectural patterns and design         | Read-only  |
| `researcher`            | Cross-reference docs, code, and web       | Read-only  |
| `implementer`           | Write code in an isolated worktree        | Read/write |
| `mapper`                | Process one chunk of a map-reduce job     | Read-only  |
| `reducer`               | Merge mapper outputs                      | Read/write |
| `judge`                 | Evaluate competing approaches             | Read/write |
| `monitor`               | Watchdog — alert on stuck or failed tasks | Read-only  |

### Built-in Presets

| Preset                  | Pattern     | Roles                                        |
|-------------------------|-------------|----------------------------------------------|
| `pr-review`             | fan-out     | security, performance, quality               |
| `full-review`           | fan-out     | security, performance, quality, architecture |
| `security-audit`        | fan-out     | security                                     |
| `implement-then-review` | pipeline    | implementer → security + quality             |
| `multi-stage-migration` | task-graph  | researcher → implementers → quality          |
| `large-codebase-audit`  | map-reduce  | mapper × N → reducer                         |
| `best-of-three`         | speculative | implementer × 3 → judge                      |
| `swarm-module-audit`    | swarm       | researcher × 4 (self-claiming)               |
| `monitored-review`      | fan-out     | security, performance, quality + watchdog    |

### Custom Roles and Presets

Add roles and presets to `config/swarm-roles.yaml`. Each role requires a
`prompt` and a `subagent_type` (`Explore` for read-only, `general-purpose` for
read/write), with optional `model` and `isolation: worktree` fields.

Presets reference global roles or define inline roles scoped to that preset:

```yaml
presets:
  my-review:
    description: "Custom review workflow"
    pattern: fan-out
    roles:
      - security-reviewer              # global role
      - name: api-contract-checker     # inline role
        subagent_type: Explore
        prompt: |
          Check API contracts for backward compatibility.
```

## Watchdog Monitoring

Add `watchdog: true` to any preset to enable a watchdog monitor. The monitor
polls the task list at a configurable interval and alerts the lead when tasks
stall, fail, or run unbalanced.

```yaml
presets:
  my-preset:
    watchdog: true
    # ...
```

Configure the polling interval in `.claude-plugin/settings.json`:

```json
{
  "monitor_cron_interval_seconds": 60
}
```

## Quality Gates

Hook scripts enforce completion standards:

- **TeammateIdle** — detects idle agents and escalates through nudge →
  warning → hard stop after repeated idle cycles
- **TaskCompleted** — validates that completed tasks include findings
- **WorktreeRemove** — cleans up counters when worktrees are removed

## Configuration Reference

### settings.json

| Key                             | Default  | Purpose                        |
|---------------------------------|----------|--------------------------------|
| `monitor_cron_interval_seconds` | 60       | Watchdog polling interval      |
| `idle_escalation_threshold`     | 3        | Idle cycles before hard stop   |
| `reviewer_model`                | `sonnet` | Default model for review roles |
| `max_agents`                    | 7        | Maximum concurrent agents      |

### Team Naming

Teams follow the format `swarm-{pattern}-{goal-slug}-{timestamp}`. The goal
slug comes from the user's description: lowercased, special characters replaced
with hyphens, truncated to 30 characters.

## Project Structure

```text
src/
├── .claude-plugin/
│   ├── plugin.json          # Plugin manifest
│   ├── marketplace.json     # Marketplace metadata
│   └── settings.json        # Runtime configuration
├── config/
│   ├── swarm-roles.yaml     # Role and preset definitions
│   └── examples/            # Example preset configurations
├── hooks/
│   ├── hooks.json           # Hook event bindings
│   └── scripts/             # Quality-gate shell scripts
└── skills/
    ├── swarm/               # Main dispatcher
    ├── swarm-fan-out/       # Fan-out pattern
    ├── swarm-pipeline/      # Pipeline and task-graph patterns
    ├── swarm-map-reduce/    # Map-reduce pattern
    ├── swarm-speculative/   # Speculative pattern
    └── swarm-swarm/         # Self-claiming pool pattern
```

## License

GPL-3.0

[Claude Code]: https://docs.anthropic.com/en/docs/claude-code
