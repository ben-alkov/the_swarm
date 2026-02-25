# Swarm Plugin v2 Design

## Goal

Expand the swarm plugin from a single-pattern tool (fan-out) to a
multi-pattern orchestration framework supporting five orchestration patterns,
with a sixth (Council) deferred to v3.

## Scope

### v2: Multi-Pattern Orchestration

- Swarm (self-claiming from task pool)
- Pipeline / Task Graph (sequential stages with dependency edges)
- Map-Reduce (parallel map + dedicated reduce)
- Speculative (competing approaches + judge selection)
- Watchdog (monitoring overlay on any pattern)

### v3 (future): Council

Multi-round debate protocol with advocates and a judge. Deferred because it
requires a structured multi-round messaging protocol that the platform does not
natively support. Needs verification of peer-to-peer SendMessage or a mediated
relay design.

## Pattern Taxonomy

The 10 documented interaction patterns reduce to 6 truly distinct ones:

| Category             | Patterns                         | Status                            |
|----------------------|----------------------------------|-----------------------------------|
| Parallel-Independent | Fan-Out, Map-Reduce, Speculative | Fan-Out implemented               |
| Sequential-Dependent | Pipeline / Task Graph (unified)  | Primitives exist                  |
| Self-Organizing      | Swarm (self-claiming)            | Primitives exist                  |
| Multi-Round          | Council                          | Deferred to v3                    |
| Meta/Overlay         | Watchdog                         | Hooks provide lightweight version |

Eliminated from the pattern list:

- **Background** is a spawn modifier (`run_in_background: true`), not a pattern
- **Leader** is always implicit (the lead in delegate mode)
- **Task Graph** strictly subsumes Pipeline (linear topology is a degenerate DAG)

## Architecture

### Config Schema Evolution

The `swarm-roles.yaml` schema gains a `pattern` field on presets. Roles stay
flat (individual agent definitions). Each pattern type has its own optional
sub-keys.

```yaml
roles:
  # Individual agent definitions — unchanged from v1
  security-reviewer:
    description: "Review code for security vulnerabilities"
    subagent_type: Explore
    model: sonnet
    prompt: |
      You are a security specialist. Review the provided code for:
      - Injection vulnerabilities (SQL, command, XSS)
      - Authentication/authorization bypass
      - Sensitive data exposure
      - Insecure deserialization
      - Dependency vulnerabilities

      Report findings with severity (critical/high/medium/low),
      affected file:line, and remediation guidance.

      Send your findings to the team lead when complete.

  performance-reviewer:
    description: "Analyze code for performance issues"
    subagent_type: Explore
    model: sonnet
    prompt: |
      You are a performance specialist. Analyze the provided code for:
      - N+1 queries and missing indexes
      - Memory leaks and excessive allocation
      - Inefficient algorithms
      - Missing caching opportunities
      - Blocking I/O in async contexts

      Report findings with impact estimate and specific fix recommendations.

      Send your findings to the team lead when complete.

  quality-reviewer:
    description: "Review code quality and maintainability"
    subagent_type: Explore
    model: sonnet
    prompt: |
      You are a code quality specialist. Review the provided code for:
      - SOLID principle violations
      - Dead code and unnecessary complexity
      - Missing or inadequate error handling
      - Test coverage gaps
      - Naming and readability issues

      Categorize issues as: critical (must fix), important (should fix),
      suggestion (nice to have).

      Send your findings to the team lead when complete.

  architecture-reviewer:
    description: "Evaluate architectural patterns and design decisions"
    subagent_type: Explore
    model: sonnet
    prompt: |
      You are an architecture specialist. Evaluate the provided code for:
      - Separation of concerns and module boundaries
      - Dependency direction and coupling
      - API design consistency
      - Error propagation patterns
      - Scalability and extensibility concerns

      Report findings with severity and specific architectural recommendations.

      Send your findings to the team lead when complete.

  researcher:
    description: "Research a topic across documentation, web, and codebase"
    subagent_type: Explore
    prompt: |
      You are a research specialist. Investigate the assigned topic by:
      - Searching the codebase for relevant patterns and implementations
      - Reading documentation and configuration files
      - Using web search for external references when needed

      Compile a structured summary with key findings, relevant code
      locations, and actionable recommendations.

      Send your findings to the team lead when complete.

  implementer:
    description: "Implement code changes in an isolated worktree"
    subagent_type: general-purpose
    isolation: worktree
    prompt: |
      You are an implementation specialist working in an isolated worktree.
      You have full read/write access to the repository.

      For your assigned task:
      - Read and understand the relevant code
      - Make the requested changes
      - Verify your changes work (run tests if applicable)
      - Commit your changes with a clear commit message

      Report what you changed and any issues encountered.

      Send your findings to the team lead when complete.

  # New roles for v2 patterns
  mapper:
    description: "Process one chunk of input, produce structured output"
    subagent_type: Explore
    prompt: |
      You are a map-reduce mapper. You will receive a specific chunk of
      work (a subset of files, modules, or endpoints).

      For your assigned chunk:
      - Analyze it thoroughly according to the goal
      - Produce structured findings with consistent format
      - Include chunk identifier in your output

      Send your structured findings to the team lead when complete.

  reducer:
    description: "Merge mapper outputs into a unified result"
    subagent_type: general-purpose
    prompt: |
      You are a map-reduce reducer. You will receive findings from
      multiple mappers.

      Your job:
      - Merge all mapper outputs into a unified result
      - Deduplicate overlapping findings
      - Resolve conflicts between mapper reports
      - Produce a single coherent output organized by theme/severity

      Send your merged result to the team lead when complete.

  judge:
    description: "Evaluate competing approaches and select a winner"
    subagent_type: general-purpose
    isolation: worktree
    prompt: |
      You are a speculative judge. Multiple implementers have taken
      competing approaches to the same problem, each in their own branch.

      Your job:
      - Check out each approach branch
      - Run tests and verify correctness
      - Evaluate code quality, maintainability, and completeness
      - Select the best approach with clear justification
      - Report the winning branch name

      Send your verdict to the team lead when complete.

  monitor:
    description: "Watch team progress and alert on anomalies"
    subagent_type: Explore
    prompt: |
      You are a watchdog monitor. Observe team progress by checking
      TaskList periodically.

      Watch for:
      - Tasks stuck in_progress without progress
      - Unbalanced workloads (one worker has many tasks, others idle)
      - Failed or blocked tasks that need intervention

      Send alerts to the team lead when anomalies detected.
      Do not intervene directly — report to the lead for decisions.

presets:
  # v1 presets — backward-compatible (pattern defaults to fan-out)
  pr-review:
    description: "Standard PR review with three specialists"
    pattern: fan-out
    roles: [security-reviewer, performance-reviewer, quality-reviewer]

  full-review:
    description: "Comprehensive review including architecture"
    pattern: fan-out
    roles:
      - security-reviewer
      - performance-reviewer
      - quality-reviewer
      - architecture-reviewer

  security-audit:
    description: "Deep security review only"
    pattern: fan-out
    roles: [security-reviewer]

  implement-and-review:
    description: "Implementation with concurrent review"
    pattern: fan-out
    roles: [implementer, quality-reviewer]

  # v2 Pipeline presets
  implement-then-review:
    description: "Sequential: implement, then review the result"
    pattern: pipeline
    stages:
      - name: implement
        roles: [implementer]
      - name: review
        roles: [security-reviewer, quality-reviewer]

  # v2 Task Graph presets
  multi-stage-migration:
    description: "Database migration with dependent steps"
    pattern: task-graph
    nodes:
      analyze:
        role: researcher
      migrate-users:
        role: implementer
        depends_on: [analyze]
      migrate-orders:
        role: implementer
        depends_on: [analyze]
      validate:
        role: quality-reviewer
        depends_on: [migrate-users, migrate-orders]

  # v2 Map-Reduce presets
  large-codebase-audit:
    description: "Audit a large codebase by splitting into chunks"
    pattern: map-reduce
    map_role: mapper
    reduce_role: reducer
    split_strategy: by-directory

  # v2 Speculative presets
  best-of-three:
    description: "Three competing implementations, judge picks winner"
    pattern: speculative
    approach_role: implementer
    judge_role: judge
    approach_count: 3
    plan_approval: true
```

### Skill Organization

Dispatcher + pattern sub-skills model:

```text
skills/
  swarm/
    SKILL.md                # thin dispatcher: reads pattern, routes
  swarm-fan-out/
    SKILL.md                # v1 behavior (renamed from swarm-dispatch)
  swarm-swarm/
    SKILL.md                # self-claiming pool orchestration
  swarm-pipeline/
    SKILL.md                # pipeline + task-graph orchestration
  swarm-map-reduce/
    SKILL.md                # map-reduce orchestration
  swarm-speculative/
    SKILL.md                # competing approaches + judge
```

The dispatcher skill (~50 lines) reads the selected preset's `pattern` field and
instructs Claude to follow the corresponding pattern skill. If `pattern` is
absent, defaults to `fan-out` for backward compatibility.

Token cost per invocation: dispatcher (~50 lines) + one pattern skill (~200
lines) = ~250 lines. Same as v1 for fan-out, cheaper than a monolith for other
patterns.

### Plugin File Structure

```text
the_swarm/
├── .claude-plugin/
│   └── plugin.json                    # version: 0.2.0
├── skills/
│   ├── swarm/
│   │   └── SKILL.md                   # dispatcher
│   ├── swarm-fan-out/
│   │   └── SKILL.md                   # fan-out (v1 behavior)
│   ├── swarm-swarm/
│   │   └── SKILL.md                   # self-claiming pool
│   ├── swarm-pipeline/
│   │   └── SKILL.md                   # pipeline + task-graph
│   ├── swarm-map-reduce/
│   │   └── SKILL.md                   # map-reduce
│   └── swarm-speculative/
│       └── SKILL.md                   # speculative + judge
├── config/
│   ├── swarm-roles.yaml               # v2 schema
│   └── examples/
│       ├── fan-out-pr-review.yaml
│       ├── swarm-module-audit.yaml
│       ├── pipeline-implement-review.yaml
│       ├── task-graph-migration.yaml
│       ├── map-reduce-audit.yaml
│       └── speculative-refactor.yaml
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── teammate-idle.sh           # pattern-aware routing
│       ├── task-completed.sh          # pattern-aware routing
│       └── lib/
│           ├── fan-out-checks.sh
│           └── pipeline-checks.sh
└── docs/
```

### Hook Evolution

Hooks become pattern-aware via team naming convention. Team names encode the
pattern: `swarm-{pattern}-{goal}-{ts}`.

```bash
# Extract pattern from team name, default to fan-out for v1 compat
PATTERN_RE='^swarm-(fan-out|swarm|pipeline|task-graph'
PATTERN_RE+='|map-reduce|speculative)-'
if [[ "$TEAM_NAME" =~ $PATTERN_RE ]]; then
  PATTERN="${BASH_REMATCH[1]}"
else
  PATTERN="fan-out"
fi

case "$PATTERN" in
  fan-out|swarm|map-reduce)
    # SendMessage check: every agent must report findings
    ;;
  pipeline|task-graph)
    # Stage-aware: check artifact/output presence, not just SendMessage
    ;;
  speculative)
    # Approach agents: check for commit; judge: check for verdict
    ;;
  *)
    exit 0  # unknown pattern, don't block
    ;;
esac
```

## Pattern Designs

### Swarm (Self-Claiming) — v2.0

Workers self-assign from a shared task pool. The lead creates tasks without
owners; workers race to claim via `TaskList` → `TaskUpdate(owner: self)`.

#### When to Use

- Large workloads with many independent, similar-sized tasks
- Tasks that don't require specialized expertise per task
- The number of tasks exceeds the number of workers

#### Orchestration Flow

1. Lead creates team + N tasks (all `pending`, no owner, no dependencies)
2. Lead spawns M workers (M ≤ N) with identical role prompts
3. Each worker loops: `TaskList` → find unclaimed → `TaskUpdate(owner, in_progress)`
   → work → `SendMessage` findings → `TaskUpdate(completed)` → repeat
4. Workers go idle when no unclaimed tasks remain
5. Lead synthesizes all findings

#### Team Naming

`swarm-swarm-{goal}-{ts}`

#### Spawn Prompt Addition

Workers receive loop instructions rather than v1's "claim your one task":

```markdown
After completing a task and sending your findings:
1. Check TaskList for unclaimed tasks
2. If unclaimed tasks exist, claim the next one and continue working
3. If no unclaimed tasks remain, go idle
```

### Pipeline / Task Graph — v2.1

Sequential stages with dependency edges. Pipeline (linear) and Task Graph
(arbitrary DAG) share one skill with a `topology` parameter.

#### Pipeline Applicability

- Multi-stage workflows where output feeds the next stage
- Implementation + review chains
- Any workflow with sequential dependencies

#### Orchestration Flow (Pipeline)

1. Lead creates team + tasks with linear `addBlockedBy` edges
2. Lead spawns agents for all stages (idle until unblocked)
3. Stage A claims unblocked task, works, sends findings, marks complete
4. Platform auto-unblocks stage B → agent claims and works
5. Repeat until final stage completes
6. Lead synthesizes chain output

#### Orchestration Flow (Task Graph)

Same as pipeline but with arbitrary dependency edges. Supports fan-in (multiple
predecessors) and fan-out (multiple successors) within the graph.

#### Context Passing Between Stages

Two mechanisms:

- **SendMessage relay**: Stage A sends findings to lead; lead forwards to
  stage B's agent via SendMessage when the task unblocks
- **Worktree chain**: Stage A commits to a worktree branch; stage B's spawn
  prompt references that branch. Requires `isolation: worktree` on both.

#### Pipeline Team Naming

`swarm-pipeline-{goal}-{ts}` or `swarm-task-graph-{goal}-{ts}`

#### Stages with Parallel Roles

Roles within a single stage run in parallel (fan-out within the stage). Stages
are sequential. This enables patterns like "3 reviewers in parallel at the
review stage, blocked on the implementation stage."

### Map-Reduce — v2.2

Fan-out with structured input splitting and a dedicated reduce phase.

#### Map-Reduce Applicability

- Large-scale analysis where input can be partitioned
- Codebase audits across many directories or modules
- Document processing at scale

#### Map-Reduce Flow

1. Lead determines the split (directories, file groups, endpoint batches)
2. Lead creates N mapper tasks (independent) + 1 reducer task (blocked by all
   mapper tasks via `addBlockedBy`)
3. Lead spawns N mapper agents + 1 reducer agent
4. Mappers work in parallel, each sends structured findings to lead
5. When all mappers complete, reducer task auto-unblocks
6. Lead forwards all mapper outputs to reducer via SendMessage
7. Reducer merges into unified output, sends to lead
8. Lead presents final result

#### Why a Reducer Teammate

Delegate mode prevents the lead from reading files, running code, or writing
output. The reducer needs `general-purpose` access to produce structured merged
artifacts.

#### Split Strategies

- `by-directory`: one mapper per top-level directory
- `by-file-count`: split files into roughly equal groups
- `manual`: lead asks user to specify the split

#### Map-Reduce Team Naming

`swarm-map-reduce-{goal}-{ts}`

### Speculative — v2.3

Run competing approaches in parallel; a judge evaluates and picks the winner.

#### Speculative Applicability

- Risky or exploratory changes where the best approach is unclear
- Refactoring where multiple strategies are viable
- Best-of-N quality improvement

#### Speculative Flow

1. Lead creates N approach tasks + 1 judge task (blocked by all)
2. Lead spawns N implementers, each with `isolation: worktree`
3. Each implementer works its approach, commits to its branch, reports
4. When all implementers complete, judge task auto-unblocks
5. Lead forwards approach summaries to judge via SendMessage
6. Judge checks out each branch, runs tests, evaluates quality
7. Judge sends verdict with winning branch to lead
8. Lead presents result; user decides whether to merge

#### Plan Approval Integration

Optionally spawn implementers with `CLAUDE_CODE_PLAN_MODE_REQUIRED`. Each
must submit a plan for lead approval before implementing. Lead approves or
rejects with feedback.

#### Speculative Team Naming

`swarm-speculative-{goal}-{ts}`

### Watchdog — v2.4

A monitoring overlay on any other pattern.

#### Watchdog Applicability

- Long-running swarms where proactive monitoring is desired
- Large teams where manual status checking is burdensome
- Any pattern where early anomaly detection adds value

#### Implementation

Not a standalone preset but a modifier flag on any preset:

```yaml
presets:
  monitored-pipeline:
    pattern: pipeline
    watchdog: true
    stages: [...]
```

When `watchdog: true`, the dispatcher spawns an additional monitor agent
alongside the pattern's normal agents. The monitor:

- Periodically checks TaskList for anomalies
- Sends alerts to lead via SendMessage
- Does not intervene directly — reports to lead for decisions

#### Relationship to Hooks

TeammateIdle and TaskCompleted hooks are synchronous gates (block/allow).
Watchdog is an asynchronous monitor (observe and report). They complement each
other: hooks enforce minimums, Watchdog detects emerging problems.

## Platform Constraints

### Hard Constraints

- **One team per session**: a lead manages one team at a time
- **No nested teams**: teammates cannot spawn sub-teams
- **Session resume does not restore teammates**: `/resume` drops live teammates;
  task list persists but processes are gone
- **Lead history not inherited**: teammates receive project context + spawn
  prompt only
- **Delegate mode is read-only**: lead cannot read files, run Bash, or write —
  coordination only. Patterns needing reduction/synthesis use dedicated
  teammates (reducer, judge)
- **Agent type fixed at spawn**: `subagent_type` cannot change after spawn
- **Worktree isolation is per-Task**: platform manages lifecycle automatically

### Capabilities Used by v2

| Capability                         | Used By                                                               |
|------------------------------------|-----------------------------------------------------------------------|
| `blocks`/`blockedBy`               | Pipeline, Task Graph, Map-Reduce reducer gate, Speculative judge gate |
| `CLAUDE_CODE_PLAN_MODE_REQUIRED`   | Speculative (optional plan approval before implementation)            |
| `plan_approval_request`/`response` | Speculative plan gates                                                |
| `isolation: worktree`              | Speculative approaches, Pipeline implementers                         |
| Task self-claiming                 | Swarm pattern (TaskList → TaskUpdate with owner)                      |
| `run_in_background: true`          | All patterns (universal spawn modifier)                               |

### Practical Scale Limits

- **Teammate count**: 3-5 is the practical sweet spot. Beyond 7, coordination
  overhead grows linearly while marginal value diminishes.
- **Token budget**: each teammate has its own context window. Long analysis tasks
  can hit limits with no mitigation mechanism.
- **Worktree count**: each worktree is a full checkout. Large repos × many
  workers = significant disk usage.
- **Lead context**: all incoming SendMessage findings accumulate in the lead's
  conversation. Instruct specialists to send concise, structured summaries.

## Superpowers Integration

Superpowers and Swarm operate on orthogonal axes:

- **Superpowers** = process discipline for individual agent quality
  (brainstorm → plan → TDD → verify)
- **Swarm** = parallelism coordination (fan-out → collect → synthesize)

### Integration Points

- **Pre-dispatch gate**: run superpowers brainstorming before deciding to
  dispatch a swarm, to decompose the work and select patterns
- **Post-synthesis verification**: apply verification-before-completion to the
  lead's synthesized report
- **TaskCompleted hook**: the swarm's internal equivalent of
  verification-before-completion at the task level

### Not Integrated

Swarm teammates should NOT run full superpowers workflows internally. The
context window overhead per teammate would be significant, and spawn prompts
cannot carry superpowers' conversational Q&A history.

## Migration Path

### Backward Compatibility

1. Rename `skills/swarm-dispatch/` to `skills/swarm-fan-out/`. Add
   `skills/swarm/` as the dispatcher with backward-compatible routing.
2. Existing presets without a `pattern` field default to `fan-out` — zero
   breakage.
3. Hook backward compatibility: v1 team names (`swarm-pr-review-...`) without a
   pattern segment fall through to fan-out behavior.

```bash
# Pattern extraction with v1 fallback
PATTERN_RE='^swarm-(fan-out|swarm|pipeline|task-graph'
PATTERN_RE+='|map-reduce|speculative)-'
if [[ "$TEAM_NAME" =~ $PATTERN_RE ]]; then
  PATTERN="${BASH_REMATCH[1]}"
else
  PATTERN="fan-out"  # v1 teams default to fan-out
fi
```

### Schema Is Additive

The v2 `swarm-roles.yaml` adds optional fields (`pattern`, `stages`, `nodes`,
`debate`, etc.) to presets. Existing presets without these fields work as
fan-out.

## Implementation Sequence

| Release | Pattern               | Core New Primitive                         |
|---------|-----------------------|--------------------------------------------|
| v2.0    | Swarm (self-claiming) | Task pool self-assignment                  |
| v2.1    | Pipeline / Task Graph | Ordered `blocks`/`blockedBy` orchestration |
| v2.2    | Map-Reduce            | Reducer role + blocking aggregation        |
| v2.3    | Speculative           | Competing branches + judge selection       |
| v2.4    | Watchdog              | Monitor agent overlay                      |
| v3.0    | Council               | Multi-round debate protocol                |

## Design Decisions

### Dispatcher + Pattern Sub-Skills (not monolith)

A thin dispatcher routes to pattern-specific skills. Each pattern skill is
self-contained (~200 lines). The dispatcher is ~50 lines. Total loaded per
invocation is ~250 lines — same as v1 for fan-out, cheaper than a monolith for
other patterns. New patterns add files without touching existing ones.

### Pipeline and Task Graph Are One Skill

Pipeline is a degenerate Task Graph (linear topology). Implementing them as one
unified skill with a `topology` parameter avoids duplication and ensures the
Task Graph design is planned from day one. The config uses `pattern: pipeline`
(with `stages` shorthand) or `pattern: task-graph` (with `nodes` + `depends_on`
edges).

### Reducer and Judge Are Teammates, Not Lead

Delegate mode prevents the lead from file operations. Map-Reduce needs a reducer
that can process and write structured output. Speculative needs a judge that can
check out branches and run tests. Both are spawned as `general-purpose`
teammates with the appropriate access.

### Team Naming Encodes Pattern

`swarm-{pattern}-{goal}-{ts}` enables hooks to route pattern-aware logic
without additional metadata files or configuration.

### Watchdog Is a Modifier, Not a Pattern

The `watchdog: true` flag on any preset adds a monitor agent alongside the
pattern's normal agents. This avoids a standalone Watchdog pattern that would
be awkward to use in isolation.

### Council Deferred to v3

Council requires multi-round structured deliberation. The platform has no native
debate protocol; it would need to be built on top of SendMessage relaying. The
open question of whether teammates can SendMessage to each other directly (peer)
vs. only to the lead (mediated) shapes the design significantly. Deferring
avoids shipping an under-designed protocol.
