---
Swarm Plugin Design

Type: Design
Date: 2026-02-17
Goal: Bring up a minimal but functional implementation of Anthropic's recently announced Agent Swarn
---

<!-- markdownlint-disable ol-prefix first-line-h1 line-length -->

## Goal

A standalone Claude Code plugin that enables parallel specialist orchestration
using the agent teams API (`TeamCreate`, `SendMessage`, `Task` with
`team_name`/`name`, `TeamDelete`).

## Scope

### v1: Parallel Specialists

Fan-out N read-only specialists (reviewers, researchers, analyzers) against the
same target, collect findings, synthesize and present to the user. No file
edits, no worktrees.

### v2 (future): Parallel Implementers

Multiple workers editing files via per-worker worktrees, with merge coordination
back to a shared feature branch.

## Architecture

### Component Overview

```text
User ──► Main Session Agent (delegate mode)
              │
              │ follows skill, becomes team lead
              │
              ├─► TeamCreate
              ├─► TaskCreate (one per role, with activeForm)
              ├─► Task+team_name+name (spawn teammates)
              │       │         │         │
              │       ▼         ▼         ▼
              │   Specialist  Specialist  Specialist
              │   (security) (perf)      (quality)
              │       │         │         │
              │       └────┬────┘─────────┘
              │            │ SendMessage (findings)
              │            ▼
              ├─► Collect & synthesize findings
              ├─► Present synthesized report to user
              │
              │ (user says "done")
              │
              ├─► SendMessage shutdown_request (each)
              ├─► Wait for shutdown_response
              └─► TeamDelete
```

The main session acts as the team lead directly using **delegate mode**
(`Shift+Tab`), which restricts available tools to coordination-only:
`TeammateTool`, `TaskCreate`, `TaskGet`, `TaskUpdate`, `TaskList`, and
`SendMessage`. This eliminates the overhead of a separate leader context window
and gives the user direct visibility into coordination.

### Display Mode

The plugin targets **in-process** display mode (all teammates run inside the
main terminal). Navigate teammates with `Shift+Up/Down`, view a teammate's
session with `Enter`, interrupt with `Escape`, toggle task list with `Ctrl+T`.

### Plugin File Structure

```text
~/.claude/plugins/swarm/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── swarm-dispatch/
│       └── SKILL.md
├── config/
│   ├── swarm-roles.yaml
│   └── examples/
│       ├── pr-review.yaml
│       ├── research.yaml
│       └── codebase-audit.yaml
└── README.md
```

### Runtime Filesystem Structure

Agent teams create the following at runtime:

```text
~/.claude/
├── teams/{team-name}/
│   ├── config.json          # members array: name, agentId, agentType
│   └── messages/{session-id}/
└── tasks/{team-name}/       # shared task list
```

### Platform Constraints

- **One team per session**: a lead can only manage one team at a time. The skill
  must check for an existing team and handle accordingly (warn user, offer
  cleanup).
- **No nested teams**: teammates cannot spawn their own teams or teammates. Only
  the lead can manage the team. This confirms the lead-only orchestration
  pattern.
- **Session resumption**: `/resume` and `/rewind` do not restore in-process
  teammates. After resuming, the lead may need to spawn new teammates.

## Components

### 1. Roles Config (`swarm-roles.yaml`)

User-editable YAML defining specialist roles and presets.

```yaml
roles:
  security-reviewer:
    description: "Review code for security vulnerabilities"
    subagent_type: Explore          # read-only agent type
    model: sonnet                   # optional
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

presets:
  pr-review:
    description: "Standard PR review with three specialists"
    roles: [security-reviewer, performance-reviewer, quality-reviewer]

  security-audit:
    description: "Deep security review only"
    roles: [security-reviewer]
```

#### Config Semantics

- `subagent_type`: maps to Task tool parameter. v1 specialists use `Explore`
  (read-only: Glob, Grep, Read, WebFetch, WebSearch — no Edit, Write, Bash).
  v2 implementers would use `general-purpose` (full tool access).
- `model`: optional; inherits from parent when omitted
- `prompt`: template; the lead prepends goal/target context before dispatching
- `presets`: named groups of roles for quick invocation

### 2. Team Lead Behavior (Main Session in Delegate Mode)

The main session enters delegate mode and orchestrates the full
parallel-specialists lifecycle.

#### Responsibilities

1. Receive goal, target, and roles from the skill
2. Enter delegate mode (`Shift+Tab`)
3. Create team via `TeamCreate`
4. Read roles config from `~/.claude/plugins/swarm/config/swarm-roles.yaml`
5. Create one task per role via `TaskCreate` with `subject`, `description`, and
   `activeForm` (e.g., `activeForm: "Reviewing security vulnerabilities"`)
6. Spawn one teammate per role via `Task` with `team_name` + `name`,
   `run_in_background: true`
7. Wait for results via teammate `SendMessage` responses
8. Synthesize findings across all specialists into a unified report
9. Present synthesized report to user
10. Await instructions (user decides next steps)
11. Shutdown teammates when instructed (`SendMessage` type `shutdown_request`)
12. Cleanup via `TeamDelete`

#### Teammate Prompt Construction

Each teammate's prompt is composed from three parts:

1. Role `prompt` from `swarm-roles.yaml`
2. Goal/context from the spawning prompt (files, PR, scope, constraints)
3. Standard instructions:
   - Identity: "Your name is {name}. You are part of team {team_name}."
   - Reporting: "Send findings to team lead via SendMessage."
   - Task claiming: "Claim your task from TaskList, mark in_progress,
     then completed when done."

#### Context Inheritance

Teammates load the same project context as a regular session: `CLAUDE.md`, MCP
servers, and skills. They also receive the spawn prompt from the lead. The
lead's conversation history does **not** carry over — all task-specific context
must be included in the spawn prompt.

#### Permission Model

Teammates inherit the lead's permission settings at spawn time. Since v1
specialists are read-only:

- Specialists use `subagent_type: Explore`, which restricts available tools to
  read-only operations (Glob, Grep, Read, WebFetch, WebSearch). This enforces
  the read-only constraint at the agent-type level regardless of inherited
  permissions.
- v2 implementers would use `subagent_type: general-purpose` with appropriate
  permission scoping.

#### Design Constraints

- Synthesizes findings into a unified report (per official guidance)
- Does NOT fix issues specialists find
- Does NOT shut down without being told to
- Does NOT proceed past reporting without user input

#### Team Naming

`swarm-{goal-slug}-{timestamp}` (e.g., `swarm-pr-review-1708200000`)

#### Error Handling

- Idle teammate without findings: message asking for status
- Crashed teammate (no response after nudge): note in report, mark task blocked
- TeamCreate failure: report error, do not proceed
- Missing roles/preset: report available options, ask for clarification

#### Hooks Integration

The plugin leverages two built-in hooks for quality gates:

- **`TeammateIdle`**: runs when a teammate is about to go idle. Exit with code 2
  to send feedback and keep the teammate working. Use this to nudge specialists
  who haven't reported findings yet.
- **`TaskCompleted`**: runs when a task is being marked complete. Exit with
  code 2 to prevent completion and send feedback. Use this to enforce minimum
  quality standards on specialist reports (e.g., reject empty findings,
  require severity ratings).

### 3. Skill (`swarm-dispatch/SKILL.md`)

Entry point that determines *when* to spawn a swarm and *how* to set it up.

#### Trigger Conditions

- User asks for review from multiple angles
- User wants parallel independent analysis
- User explicitly asks for "swarm" or "team review"
- Task benefits from diverse concurrent specialist perspectives

#### Not Applicable When

- Single-perspective tasks
- Sequential dependencies between workers
- Simple questions or explorations
- A team already exists in the current session (warn user, offer cleanup first)

Note: parallel implementation (workers editing files) requires worktree-based
isolation, planned for v2 (parallel-implementers pattern).

#### Workflow

1. Identify the goal (what is being reviewed/analyzed?)
2. Identify the target (which files, PR, scope?)
3. Select roles (from preset or individual roles)
4. Check for existing team (one team per session constraint)
5. Confirm with user (show specialists, target, proceed?)
6. Enter delegate mode and begin orchestration

#### User Confirmation

Before spawning, the skill presents:

```text
I'll dispatch a swarm with these specialists:
- security-reviewer: Review for vulnerabilities
- performance-reviewer: Analyze performance issues
- quality-reviewer: Code quality and maintainability

Target: [files/PR/scope]

Proceed?
```

No surprise token costs.

## Task Management

### Task Fields

Each task created via `TaskCreate` includes:

- `subject`: brief imperative title (e.g., "Review authentication module for
  security vulnerabilities")
- `description`: detailed scope, target files, and reporting expectations
- `activeForm`: present-continuous label shown in spinner while in progress
  (e.g., "Reviewing authentication security")

### Task Dependencies

v1 tasks are independent (no dependencies between specialists). The task system
supports dependency tracking via `blocks`/`blockedBy` fields on `TaskUpdate`
(and `addBlocks`/`addBlockedBy` for incremental updates). These become relevant
for v2 pipeline patterns where tasks have sequential dependencies.

### Task Lifecycle

1. Lead creates tasks (`pending`, no owner)
2. Teammate claims task via `TaskUpdate` (set `owner`, status `in_progress`)
3. Teammate completes work, sends findings via `SendMessage`
4. Teammate marks task `completed` via `TaskUpdate`
5. `TaskCompleted` hook runs — can reject completion if quality standards not met

## SendMessage Types Reference

### `message`

DM to one teammate. Parameters: `recipient`, `content`, `summary`.

### `broadcast`

Message all teammates (use sparingly). Parameters: `content`, `summary`.

### `shutdown_request`

Request graceful shutdown. Parameters: `recipient`, `content`.

### `shutdown_response`

Respond to shutdown request. Parameters: `request_id`, `approve`, `content`.

### `plan_approval_response` (v2)

Approve/reject teammate plan. Parameters: `request_id`, `recipient`, `approve`,
`content`.

## Environment Variables

Platform-provided, read-only. Set automatically by Claude Code at runtime:

- `CLAUDE_CODE_TEAM_NAME`: name of the agent team this teammate belongs to.
  Available but not required for v1 (team context is in the spawn prompt).
- `CLAUDE_CODE_PLAN_MODE_REQUIRED`: auto-set to `true` on teammates that
  require plan approval. Not used in v1 (read-only specialists). Relevant for
  v2 implementers where plan approval gates are needed.

## Design Decisions

### Main Session as Team Lead (Delegate Mode)

The main session acts as team lead directly using delegate mode, rather than
spawning a separate leader agent. This eliminates one level of indirection,
reduces token cost (no separate leader context window), and gives the user
direct visibility and control over coordination.

Delegate mode restricts the lead to coordination-only tools: `TeammateTool`,
`TaskCreate`, `TaskGet`, `TaskUpdate`, `TaskList`, and `SendMessage`. This
mechanically enforces the constraint that the lead does not implement or fix
issues — it orchestrates.

### Lead Synthesizes Findings

Per official guidance, the lead synthesizes findings across all specialists into
a unified report. This provides the user with a coherent summary rather than
disconnected raw output from each specialist. The user can always request raw
findings or drill into individual specialist reports.

### Leader Does Not Auto-Shutdown

The user controls when the team shuts down. This matches the "leader-controlled"
lifecycle preference and prevents premature cleanup.

### Roles Are Composable

Users define individual roles and group them into presets. The same
security-reviewer role can appear in a pr-review preset, a security-audit
preset, or be selected individually.

### Read-Only Specialists via Agent Type

v1 specialists use `subagent_type: Explore` which provides only read-only tools
(Glob, Grep, Read, WebFetch, WebSearch — no Edit, Write, Bash, Task). This
enforces the read-only constraint at the platform level rather than relying on
prompt instructions alone, regardless of the lead's inherited permission
settings.

### Teammate Context Is Spawn-Prompt Only

Teammates load project context (CLAUDE.md, MCP servers, skills) but not the
lead's conversation history. All task-specific context must be in the spawn
prompt. This is a platform constraint, not a design choice.

## Future Work (v2)

### Parallel Implementers Pattern

- Workers edit files via per-worker git worktrees
- Use `subagent_type: general-purpose` for full tool access
- Commits merge onto a shared feature branch
- Leader (or merge agent) handles conflict resolution
- Integrates with `superpowers:using-git-worktrees`
- `CLAUDE_CODE_PLAN_MODE_REQUIRED` becomes relevant for gating implementer work

### Plan Approval Workflow

- Teammates with `plan_mode_required` work in read-only plan mode until approved
- Lead receives `plan_approval_request` messages, responds with
  `plan_approval_response` (approve/reject with feedback)
- Rejected teammates revise and resubmit
- Useful for risky or complex implementation tasks

### Superpowers Integration

- Brainstorming gate before dispatch
- Verification-before-completion on synthesized results
- Leader invokes Superpowers process skills as appropriate

### Additional Patterns

- Pipeline (sequential stages using `blocks`/`blockedBy` for auto-unblocking)
- Self-organizing swarm (workers claim from a pool)
- Configurable display mode (tmux split panes for visual monitoring)
