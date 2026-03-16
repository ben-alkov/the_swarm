---
Claude Code Upstream Docs (https://code.claude.com/docs/en/agent-teams) Alignment

Type: Design
Date: 2026-03-16
Goal: Implement actionable findings from the "Official Agent Teams vs The-Swarm" impact spike
---

# Agent Teams Alignment — Design Spec

Align the-swarm with upstream Claude Code Agent Teams capabilities
documented at `code.claude.com/docs/en/agent-teams.md`. All features
designed; user selects which to implement.

## Context

Comparison of upstream Agent Teams docs (v2.1.32+) with the-swarm's
implementation revealed 7 gap areas. This spec designs features to
close those gaps, classified into a stable core (established upstream
APIs) and experimental extensions (upstream behaviors that may change).

## Stability Classification

### Stable Core

Features built on established upstream APIs unlikely to change

- Feature flag prerequisite documentation and runtime detection
- Broadcast messaging for shutdown and pipeline relay (pending
  verification that `SendMessage` supports broadcast targets — if
  not, these features reduce to shutdown-protocol alignment only)
- Shutdown protocol alignment (rejection handling)
- Display mode preset hints
- Human-to-teammate interaction awareness

### Experimental Extensions

Features depending on upstream behaviors still marked experimental

- Debate pattern (new peer-to-peer orchestration)
- Two-gate peer messaging flag
- Teammate self-discovery (roster injection + config path)

## Architecture: Shared Prompt Library

### File

`src/config/prompt-fragments.md`

A markdown file containing named prompt blocks that pattern skills
reference during prompt construction. Each block has a heading (the
fragment name) and the exact text to inject into teammate prompts.

### Fragments

| Fragment             | Injected when                             | Content                                                                                                                        |
|----------------------|-------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| `human-interaction`  | Always (all patterns)                     | Tells teammate they may receive direct messages from the user via `Shift+Down`. Instructs them to respond naturally.           |
| `peer-roster`        | `peer_messaging` active or debate pattern | Lists all teammate names and roles. Includes `~/.claude/teams/{team-name}/config.json` path as fallback for dynamic discovery. |
| `shutdown-protocol`  | Always (all patterns)                     | Standard shutdown acknowledgment — respond to `shutdown_request` with `shutdown_response` (including `request_id`) and exit.   |

### How Pattern Skills Reference Them

Each pattern skill's prompt construction section includes a new part

````markdown
#### Part N: Shared Prompt Fragments

Include the following fragments from
`$CLAUDE_PLUGIN_ROOT/config/prompt-fragments.md`

- `human-interaction`
- `shutdown-protocol`
- `peer-roster` (only if peer_messaging is active)
````

The lead reads the file and inlines the relevant blocks into each
teammate's spawn prompt. No runtime file reads by teammates for
standard fragments.

## Feature: Feature Flag Prerequisite

### Documentation

Add to `README.md` a **Prerequisites** section

````markdown
## Prerequisites

- Claude Code v2.1.32 or later (`claude --version`)
- Agent Teams enabled

  ```json
  // settings.json
  {
    "env": {
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
    }
  }
  ```
````

Add to `plugin.json`

```json
"prerequisites": {
  "experimental_flags": ["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"],
  "min_version": "2.1.32"
}
```

Informational field — machine-readable for future tooling, documents
the dependency in the canonical metadata location.

### Runtime Detection

In `src/skills/swarm/SKILL.md`, add between "Identify goal and
target" and "Read roles config"

> **Step 1.5: Verify Agent Teams availability**
>
> Attempt to verify `TeamCreate` tool availability. If unavailable
> or the feature is disabled, present this message and abort
>
> *"Agent Teams is not enabled. Add
> `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to your settings.json env
> block or set it in your shell environment. See the-swarm README
> for details."*

**Detection approach:** Attempt a probe `TeamCreate` with a
disposable name (e.g., `swarm-probe-{timestamp}`), then immediately
`TeamDelete` it. This is the most reliable method — tool-availability
checks can false-positive, and catching the first real `TeamCreate`
failure wastes user time on confirmation and role resolution before
surfacing the error. The probe adds one round-trip but guarantees an
accurate signal before any real work begins.

## Feature: Broadcast Messaging

### Verified API Shape

`SendMessage` supports broadcast via `to: "*"`, which sends the
message to all teammates except the sender. Each broadcast sends a
separate message per teammate — costs scale linearly with team size.

**Constraint:** Broadcast only works with plain text messages.
Structured protocol messages (`shutdown_request`,
`shutdown_response`, `plan_approval_response`) require a specific
recipient name and **cannot** be broadcast.

Plain text messages require a `summary` field (5-10 word UI
preview).

### Impact on Shutdown

Broadcast **cannot** carry structured `shutdown_request` messages.
Shutdown remains per-agent only (see Shutdown Protocol Alignment).

The original design proposed broadcast-first shutdown with per-agent
fallback. This is not possible given the API constraint. Task 3
(per-agent structured shutdown) is the complete shutdown solution.

### Broadcast for Relay

In pipeline skill step 8 (relay context between stages), when
forwarding findings to a multi-agent stage

**Current:** iterate `SendMessage` to each downstream agent.
**New:** broadcast findings to all agents in the downstream stage
via `SendMessage({ to: "*", message: "<findings>",
summary: "Stage N findings relay" })`. Fall back to per-agent
iteration if broadcast fails at runtime.

This is valid because relay content is plain text, not a structured
protocol message.

## Feature: Shutdown Protocol Alignment

Keep `SendMessage` as the transport. Align message format with
upstream schema.

`SendMessage` accepts structured protocol objects in the `message`
field. Shutdown uses two message types:

- **Lead sends:**

  ```json
  SendMessage({
    to: "<name>",
    message: { type: "shutdown_request",
               reason: "user requested cleanup" }
  })
  ```

- **Teammate approves:**

  ```json
  SendMessage({
    to: "team-lead",
    message: { type: "shutdown_response",
               request_id: "<from request>",
               approve: true }
  })
  ```

- **Teammate rejects:**

  ```json
  SendMessage({
    to: "team-lead",
    message: { type: "shutdown_response",
               request_id: "<from request>",
               approve: false,
               reason: "still processing task X" }
  })
  ```

Key fields:

- `approve` (not `approved`) — boolean
- `request_id` — extracted from the incoming `shutdown_request`,
  required in all responses

**Constraint:** Structured protocol messages (shutdown, plan
approval) **cannot** be broadcast. The `to` field must be a
specific teammate name, not `"*"`. Shutdown requests must be sent
per-agent.

**New behavior on rejection:** the lead reports the rejection reason
to the user and asks how to proceed (force shutdown or wait).
Currently the-swarm nudges once then proceeds regardless.

## Feature: Display Mode Hints

### Preset Configuration

Optional `display_mode` field in `swarm-roles.yaml` presets

```yaml
best-of-three:
  display_mode: tmux
```

Valid values: `tmux`, `in-process`, or absent (no hint).

### Where It Surfaces

In the dispatcher's confirmation step, if the preset has a
`display_mode` hint, append

```text
This preset works well with split-pane display. To enable:
  claude --teammate-mode tmux
Or set teammateMode: "tmux" in settings.json.
```

Advisory only — never changes runtime behavior. User's
`teammateMode` setting takes precedence.

### Initial Assignments

- `best-of-three` (speculative) → `tmux`
- `code-debate` (debate) → `tmux`
- All others → no hint

## Feature: Human Interaction Awareness

### Prompt Fragment

The `human-interaction` fragment injected into every teammate

```markdown
## Direct User Interaction

You may receive messages directly from the user (not just from the
team lead). The user can cycle to your session using Shift+Down.
Respond naturally to direct user messages — answer questions, accept
redirected instructions, or provide status updates. Continue your
assigned task unless the user explicitly redirects you.
```

### Dispatch Confirmation

After the user confirms the dispatch plan, the dispatcher appends

```text
Tip: Press Shift+Down to cycle through teammates and message them
directly.
```

Single location in the dispatcher skill — all patterns inherit it.

### Combined Dispatcher Confirmation Template

The dispatcher's confirmation step (Step 4 in the current skill)
receives additions from three features. The combined template, in
order

```text
I'll dispatch a {pattern} with these specialists

- {role-1}: {description}
- {role-2}: {description}
...

Target: {files/PR/scope}

{IF preset has display_mode hint:}
This preset works well with split-pane display. To enable:
  claude --teammate-mode tmux
Or set teammateMode: "tmux" in settings.json.

{IF preset has peer_messaging: allowed:}
This preset supports peer messaging between specialists.
Enable peer messaging for this run? (Specialists will share
findings with each other, not just the lead. Uses more tokens.)
[y/N]

Proceed?
```

After the user confirms, append

```text
Tip: Press Shift+Down to cycle through teammates and message them
directly.
```

## Feature: Debate Pattern

### New Skill

`src/skills/swarm-debate/SKILL.md`

### Routing

Add to dispatcher routing table

| Pattern  | Skill          |
|----------|----------------|
| `debate` | `swarm-debate` |

### How It Differs from Fan-Out

|               | Fan-Out                       | Debate                                     |
|---------------|-------------------------------|--------------------------------------------|
| Communication | Hub-and-spoke                 | Peer-to-peer + lead moderation             |
| Findings      | Independent, lead synthesizes | Agents challenge and refine each other's   |
| Output        | Lead-authored report          | Agent-debated conclusions with dissent log |
| Token cost    | Lower                         | Significantly higher                       |

### Flow

1. **Identify goal, target, roles** — same as fan-out
2. **Confirm with user** — includes token-cost warning:
   *"Debate pattern uses significantly more tokens than fan-out due
   to peer messaging. Proceed?"*
3. **Create team and tasks** — one task per role, plus a synthesis
   task assigned to the lead
4. **Spawn specialists** — each gets `peer-roster` and
   `human-interaction` prompt fragments, plus debate-specific
   instructions

   ````markdown
   ## Debate Protocol

   After completing your initial analysis, you MUST

   1. Send your initial findings to ALL other specialists via
      SendMessage
   2. Read findings from other specialists
   3. Challenge findings you disagree with — send a rebuttal to
      that specialist directly AND send a copy to the team lead
      (two separate SendMessage calls — there is no CC mechanism)
   4. Defend or revise your own findings when challenged
   5. After at most 2 rounds of exchange, send your FINAL position
      to the team lead, noting

      - Findings you're confident in
      - Findings revised after peer challenge
      - Unresolved disagreements with specific peers
   ````

5. **Lead moderates** — monitors exchange. Nudges if debate stalls
   (agents idle without final positions). Calls time if debate
   becomes circular (same points repeated).
6. **Present debate report**

   ````markdown
   ## Debate Report

   **Goal:** {goal}
   **Target:** {target}
   **Participants:** {list}

   ### Consensus Findings
   {findings all specialists agreed on}

   ### Revised Findings
   {findings that changed after peer challenge, with
   original → revised}

   ### Unresolved Disagreements
   {specialist A says X, specialist B says Y, neither conceded}

   ### Summary
   {overall assessment, confidence based on consensus ratio}
   ````

7. **Shutdown** — broadcast shutdown

### Preset

```yaml
code-debate:
  description: "Adversarial review — specialists challenge each other"
  pattern: debate
  display_mode: tmux
  roles: [security-reviewer, performance-reviewer, quality-reviewer]
```

### Hook Behavior

Add `debate` case to `teammate-idle.sh` pattern switch with
two-stage nudge

- **Stage 1 check:** has the teammate sent initial findings to peers?
  Heuristic: check transcript for SendMessage to any non-lead
  recipient
  - If no: nudge with "You haven't shared your initial findings
    with other specialists yet. Complete your analysis and send
    findings to all peers via SendMessage."
- **Stage 2 check:** has the teammate sent a final position to the
  lead? Heuristic: check transcript for SendMessage to the lead
  containing "final" or "position".
  - If no: nudge with "You haven't sent your final position to
    the team lead yet. Consolidate your findings (including any
    peer challenges) and send your final position."
- Allow idle only after stage 2 passes

## Feature: Two-Gate Peer Messaging Flag

### Gate 1: Preset Enablement

Optional field in `swarm-roles.yaml` presets

```yaml
pr-review:
  peer_messaging: allowed
```

Valid values: `allowed` or absent. The word "allowed" signals
capability, not default behavior.

Applicable patterns: fan-out, swarm, speculative. Not pipeline or
map-reduce (lead relay is structural). Debate has peer messaging by
definition — the flag is redundant and debate presets MUST NOT
include `peer_messaging: allowed` (to prevent confusion about
whether the flag controls debate behavior — it does not).

### Gate 2: Per-Invocation User Activation

During the dispatcher's confirmation step, if the preset has
`peer_messaging: allowed`, append

```text
This preset supports peer messaging between specialists.
Enable peer messaging for this run? (Specialists will share
findings with each other, not just the lead. Uses more tokens.)
[y/N]
```

Default is no. Only explicit "yes" activates peer messaging for that
invocation. The dispatcher passes `peer_messaging_active: true` to
the pattern skill conversationally — the same way goal, target, and
preset are passed today (included in the lead's working context when
it reads and follows the pattern skill). This is not a typed
parameter; it is a note in the dispatcher's "pass through" context.

### Prompt Injection When Active

The pattern skill includes the `peer-roster` fragment and adds
lightweight peer instructions (softer than debate protocol)

````markdown
## Peer Collaboration (Optional)

Other specialists on your team: {roster}. You may message them
directly via SendMessage if you discover findings relevant to
their domain. This is optional — prioritize completing your own
analysis and reporting to the lead. Peer messages are a bonus,
not a requirement.
````

When inactive, prompt construction is unchanged — no roster, no
peer instructions.

### Initial Presets with `peer_messaging: allowed`

- `pr-review`
- `full-review`

Others can be added after validation.

## Feature: Teammate Self-Discovery

Two mechanisms, both included when peer messaging is active:

### Roster Injection (Immediate)

The `peer-roster` prompt fragment includes

````markdown
## Team Roster

Your teammates:
- security-reviewer: security specialist
- performance-reviewer: performance specialist
- quality-reviewer: quality specialist

You can message any teammate by name via SendMessage.
````

Populated at spawn time from the resolved preset roles.

### Config Path Fallback (Dynamic)

The same fragment includes

```text
For the latest team membership (if teammates join or leave during
the session), read: ~/.claude/teams/{team-name}/config.json
```

Future-proofing for dynamic team membership. Low cost to include.

**Verified:** `~/.claude/teams/{team-name}/config.json` exists and
contains a `members` array with `name`, `agentId`, and `agentType`
per member. The `TeamCreate` tool documentation confirms this path.
The config-path fallback in `peer-roster` is valid.

## Files Modified

| File                                      | Changes                                                                                         |
|-------------------------------------------|-------------------------------------------------------------------------------------------------|
| `src/skills/swarm/SKILL.md`               | Feature-flag check step, display-mode hint, peer-messaging gate in confirmation, debate routing |
| `src/skills/swarm-fan-out/SKILL.md`       | Reference prompt-fragments (part 4), conditional peer-messaging prompt, broadcast shutdown      |
| `src/skills/swarm-pipeline/SKILL.md`      | Reference prompt-fragments, broadcast relay + shutdown                                          |
| `src/skills/swarm-swarm/SKILL.md`         | Reference prompt-fragments, conditional peer-messaging prompt, broadcast shutdown               |
| `src/skills/swarm-map-reduce/SKILL.md`    | Reference prompt-fragments, broadcast shutdown                                                  |
| `src/skills/swarm-speculative/SKILL.md`   | Reference prompt-fragments, conditional peer-messaging prompt, broadcast shutdown               |
| `src/hooks/scripts/teammate-idle.sh`      | Add `debate` case with two-stage nudge to pattern switch                                        |
| `src/hooks/scripts/lib/pattern-detect.sh` | Add `debate` to PATTERN_RE alternation                                                          |
| `src/config/swarm-roles.yaml`             | Add `display_mode`, `peer_messaging` fields to presets; add `code-debate` preset                |
| `src/.claude-plugin/plugin.json`          | Add `prerequisites` field                                                                       |
| `README.md`                               | Add prerequisites section                                                                       |

## Future: Plan Approval Protocol

Upstream Agent Teams supports a plan approval workflow: teammates
spawned with `mode: "plan"` work in read-only plan mode until the
lead approves their approach. The `SendMessage` protocol includes
`plan_approval_request` (sent automatically when a teammate calls
`ExitPlanMode`) and `plan_approval_response` (approve with
`approve: true` or reject with `approve: false` and `feedback`).

This could enhance the-swarm's speculative pattern (approve
implementation plans before agents begin coding) and any pattern
where up-front plan validation reduces wasted work. Not in scope
for this alignment pass — noted for future design.

## Files Created

| File                               | Purpose                                                                        |
|------------------------------------|--------------------------------------------------------------------------------|
| `src/config/prompt-fragments.md`   | Shared prompt blocks: `human-interaction`, `peer-roster`, `broadcast-shutdown` |
| `src/skills/swarm-debate/SKILL.md` | Debate pattern orchestration skill                                             |
