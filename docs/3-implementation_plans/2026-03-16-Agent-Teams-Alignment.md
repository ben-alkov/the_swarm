# Agent Teams Alignment — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development
> (if subagents available) or superpowers:executing-plans to implement this plan.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close gaps between the-swarm and upstream Claude Code Agent Teams
capabilities (feature flag detection, broadcast/shutdown, display modes, human
interaction, debate pattern, peer messaging).

**Architecture:** Shared prompt library (`prompt-fragments.md`) holds
cross-cutting prompt blocks referenced by all pattern skills. Features are
independently implementable — skip any task whose feature you don't want. Task
dependencies are noted; skipping a dependency means skipping its dependents.

**Tech Stack:** Markdown skills, YAML config, Bash hooks, JSON metadata. No
compiled code. Verification via `markdownlint-cli2`, `shellcheck`, `yq`,
`yamlfmt`, `jq`.

**Spec:** `docs/2-designs/2026-03-16-Agent-Teams-Alignment.md`

---

## Dependency Graph

```text
Task 1 (prompt library)
├── Task 5 (display + human interaction + confirmation template)
│   ├── Task 6 (debate pattern)
│   └── Task 7 (peer messaging)
└── (no dependency)
    ├── Task 2 (feature flag prerequisite)
    ├── Task 3 (shutdown protocol)
    └── Task 4 (broadcast relay — pipeline only)
```

Tasks 2, 3, 4 are independent of each other and of Task 1. Tasks 5–7
depend on Task 1. The user may select any subset respecting these edges.

**Note:** Task 5 adds the `peer_messaging` gate to the dispatcher confirmation
template, but the pattern skills only act on the gate's answer when Task 7 is
also implemented. Implementing Task 5 without Task 7 means the user gets
prompted about peer messaging but nothing changes in teammate behavior.

---

## Pre-Implementation Verification

Before beginning any task, verify these assumptions documented in the spec:

- [x] **V1: Broadcast SendMessage** — `SendMessage` supports `to: "*"` for
  broadcast. **However**, structured protocol messages (`shutdown_request`,
  `shutdown_response`, `plan_approval_response`) **cannot** be broadcast —
  they require a specific recipient name. Task 4 scope reduced to pipeline
  relay only (plain text broadcast). Shutdown remains per-agent (Task 3).

- [x] **V2: Team config path** — confirmed via `TeamCreate` tool docs.
  `~/.claude/teams/{team-name}/config.json` exists and contains a `members`
  array with `name`, `agentId`, and `agentType` per member. The `peer-roster`
  config-path fallback is valid.

---

## Chunk 1: Foundation and Independent Features

### Task 1: Shared Prompt Library

Create the prompt-fragments file that all pattern skills will reference.

**Files:**

- Create: `src/config/prompt-fragments.md`

- [ ] **Step 1: Create prompt-fragments.md**

````markdown
# Prompt Fragments

Named prompt blocks for pattern skills to inline into teammate
spawn prompts. The lead reads this file and includes the relevant
sections.

## human-interaction

You may receive messages directly from the user (not just from the
team lead). The user can cycle to your session using Shift+Down.
Respond naturally to direct user messages — answer questions, accept
redirected instructions, or provide status updates. Continue your
assigned task unless the user explicitly redirects you.

## shutdown-protocol

When you receive a structured `shutdown_request` message via
SendMessage, respond with a `shutdown_response` and stop working:

```json
SendMessage({
  to: "team-lead",
  message: { type: "shutdown_response",
             request_id: "<from the request>",
             approve: true }
})
```

If you cannot stop immediately (e.g., mid-commit or mid-test),
reject with a reason:

```json
SendMessage({
  to: "team-lead",
  message: { type: "shutdown_response",
             request_id: "<from the request>",
             approve: false,
             reason: "<why>" }
})
```

The team lead will decide whether to wait or force shutdown.

## peer-roster

Your teammates:
{roster — populated at spawn time by the lead}

You can message any teammate by name via SendMessage.

For the latest team membership (if teammates join or leave during
the session), read: `~/.claude/teams/{team-name}/config.json`
````

Note: The `{roster}` and `{team-name}` placeholders are filled by the lead at
spawn time. The file is a template, not a literal prompt.

- [ ] **Step 2: Verify lint**

Run: `markdownlint-cli2 src/config/prompt-fragments.md`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add src/config/prompt-fragments.md
git commit -m "feat(config): add shared prompt-fragments library

Cross-cutting prompt blocks for human interaction awareness,
shutdown protocol, and peer roster injection. Referenced by
pattern skills during teammate prompt construction."
```

---

### Task 2: Feature Flag Prerequisite

Document the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` requirement and add runtime
detection. Independent of Task 1.

**Files:**

- Modify: `README.md` (add Prerequisites section after Requirements)
- Modify: `src/.claude-plugin/plugin.json` (add `prerequisites` field)
- Modify: `src/skills/swarm/SKILL.md` (add Step 1.5)

- [ ] **Step 1: Edit README.md — add Prerequisites section**

After the existing `## Requirements` section (line 8-11), add:

```markdown
## Prerequisites

- Claude Code v2.1.32 or later (`claude --version`)
- Agent Teams enabled in Claude Code settings:

  ```json
  // settings.json
  {
    "env": {
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
    }
  }
  ```
```

- [ ] **Step 2: Edit plugin.json — add prerequisites field**

After the `"license"` field (line 12), add:

```json
"prerequisites": {
  "experimental_flags": ["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"],
  "min_version": "2.1.32"
},
```

- [ ] **Step 3: Edit dispatcher SKILL.md — add Step 1.5**

In `src/skills/swarm/SKILL.md`, between the current Step 1 ("Identify goal and
target") and Step 2 ("Read roles config"), insert:

```markdown
1.5. **Verify Agent Teams availability** — attempt a probe
   `TeamCreate` with a disposable name
   (`swarm-probe-{current-timestamp}`), then immediately
   `TeamDelete` it. If `TeamCreate` fails or is unavailable, abort
   with: *"Agent Teams is not enabled. Add
   `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to your settings.json env
   block or set it in your shell environment. See the-swarm README
   for details."*
```

- [ ] **Step 4: Verify lints**

Run:

```bash
markdownlint-cli2 README.md src/skills/swarm/SKILL.md
jsonlint src/.claude-plugin/plugin.json
```

Expected: 0 errors each

- [ ] **Step 5: Commit**

```bash
git add README.md src/.claude-plugin/plugin.json src/skills/swarm/SKILL.md
git commit -m "feat(prereqs): document and detect Agent Teams feature flag

Add prerequisites section to README and plugin.json. Add probe-based
runtime detection to dispatcher (Step 1.5) that verifies TeamCreate
availability before proceeding."
```

---

### Task 3: Shutdown Protocol Alignment

Standardize shutdown message format across all pattern skills. Add rejection
handling. Independent of Tasks 1 and 2.

**Files:**

- Modify: `src/skills/swarm-fan-out/SKILL.md` (Step 10)
- Modify: `src/skills/swarm-pipeline/SKILL.md` (Step 12)
- Modify: `src/skills/swarm-swarm/SKILL.md` (Step 11)
- Modify: `src/skills/swarm-map-reduce/SKILL.md` (Step 12)
- Modify: `src/skills/swarm-speculative/SKILL.md` (Step 13)

- [ ] **Step 1: Define the replacement shutdown text**

In each pattern skill's shutdown step, replace the current shutdown procedure
with:

````markdown
1. Send shutdown request to each teammate individually via
   `SendMessage` (structured messages cannot be broadcast):

   ```json
   SendMessage({
     to: "<teammate-name>",
     message: { type: "shutdown_request",
                reason: "user requested cleanup" }
   })
   ```

   (include the monitor agent if `watchdog: true` was active)
2. Wait for `shutdown_response` from each:
   - `{ type: "shutdown_response", request_id: "...",
     approve: true }` — agent will exit gracefully
   - `{ type: "shutdown_response", request_id: "...",
     approve: false, reason: "<explanation>" }` — report the
     rejection reason to the user and ask: force shutdown or wait?
3. If an agent does not respond after a reasonable wait, send one
   nudge message. If still unresponsive, proceed.
4. Call `TeamDelete` to clean up. If it fails due to active agents,
   retry after unresponsive agents have timed out.
````

- [ ] **Step 2: Apply to swarm-fan-out/SKILL.md**

Replace Step 10 ("Shutdown and Cleanup") body with the text from Step 1.

- [ ] **Step 3: Apply to swarm-pipeline/SKILL.md**

Replace Step 12 ("Shutdown and Cleanup") body.

- [ ] **Step 4: Apply to swarm-swarm/SKILL.md**

Replace Step 11 ("Shutdown and Cleanup") body.

- [ ] **Step 5: Apply to swarm-map-reduce/SKILL.md**

Replace Step 12 ("Shutdown and Cleanup") body.

- [ ] **Step 6: Apply to swarm-speculative/SKILL.md**

Replace Step 13 ("Shutdown and Cleanup") body.

- [ ] **Step 7: Verify lints**

Run:

```bash
markdownlint-cli2 src/skills/swarm-fan-out/SKILL.md \
  src/skills/swarm-pipeline/SKILL.md \
  src/skills/swarm-swarm/SKILL.md \
  src/skills/swarm-map-reduce/SKILL.md \
  src/skills/swarm-speculative/SKILL.md
```

Expected: 0 errors

- [ ] **Step 8: Commit**

```bash
git add src/skills/swarm-fan-out/SKILL.md \
  src/skills/swarm-pipeline/SKILL.md \
  src/skills/swarm-swarm/SKILL.md \
  src/skills/swarm-map-reduce/SKILL.md \
  src/skills/swarm-speculative/SKILL.md
git commit -m "feat(shutdown): align protocol with upstream Agent Teams

Standardize shutdown message format with structured JSON types.
Add rejection handling — teammates can refuse shutdown with a
reason, which the lead surfaces to the user."
```

---

## Chunk 2: Broadcast, Display, and Cross-Cutting Updates

### Task 4: Broadcast Relay for Pipeline

Add broadcast for plain text relay in the pipeline pattern. Broadcast
**cannot** carry structured protocol messages (shutdown, plan approval), so
this task is limited to pipeline relay only. Shutdown remains per-agent
(Task 3). Independent of Task 3.

**Files:**

- Modify: `src/skills/swarm-pipeline/SKILL.md` (Step 8)

- [ ] **Step 1: Add broadcast relay to pipeline skill**

In `src/skills/swarm-pipeline/SKILL.md` Step 8 ("Relay Context Between
Stages"), where the lead forwards findings to the next stage's agents, change
from iterating SendMessage to:

```markdown
3. Broadcast findings to all downstream agents via
   `SendMessage({ to: "*", message: "<findings summary>",
   summary: "Stage N findings relay" })`. If broadcast fails,
   fall back to per-agent iteration. End the message with: "You
   may now claim your task and begin work."
```

- [ ] **Step 2: Verify lint**

Run: `markdownlint-cli2 src/skills/swarm-pipeline/SKILL.md`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add src/skills/swarm-pipeline/SKILL.md
git commit -m "feat(broadcast): pipeline relay via broadcast

Pipeline relay step broadcasts findings to all downstream agents
via SendMessage(to: '*'). Falls back to per-agent iteration if
broadcast fails. Shutdown remains per-agent (structured messages
cannot be broadcast)."
```

---

### Task 5: Display Mode Hints, Human Interaction, and Confirmation Template

Add display mode hints to presets, human interaction awareness to all teammates,
and the combined dispatcher confirmation template. Depends on Task 1 (prompt
library must exist).

**Files:**

- Modify: `src/config/swarm-roles.yaml` (add `display_mode` to `best-of-three`)
- Modify: `src/skills/swarm/SKILL.md` (confirmation template, post-confirm tip)
- Modify: `src/skills/swarm-fan-out/SKILL.md` (prompt-fragment reference)
- Modify: `src/skills/swarm-pipeline/SKILL.md` (prompt-fragment reference)
- Modify: `src/skills/swarm-swarm/SKILL.md` (prompt-fragment reference)
- Modify: `src/skills/swarm-map-reduce/SKILL.md` (prompt-fragment reference)
- Modify: `src/skills/swarm-speculative/SKILL.md` (prompt-fragment reference)

- [ ] **Step 1: Edit swarm-roles.yaml — add display_mode to best-of-three**

In `src/config/swarm-roles.yaml`, add `display_mode: tmux` to the
`best-of-three` preset (after the `description` line):

```yaml
  best-of-three:
    description: "Three competing implementations, judge picks winner"
    display_mode: tmux
    pattern: speculative
```

- [ ] **Step 2: Verify YAML lint**

Run: `yq --exit-status 'tag == "!!map" or tag == "!!seq"' src/config/swarm-roles.yaml >/dev/null`
Expected: 0 errors

- [ ] **Step 3: Edit dispatcher SKILL.md — combined confirmation template**

In `src/skills/swarm/SKILL.md`, in the confirmation step (Step 4), replace the
current confirmation text with the combined template from the spec:

```markdown
Present the dispatch plan using `AskUserQuestion`:

    I'll dispatch a {pattern} with these specialists:
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

After the user confirms, append:

    Tip: Press Shift+Down to cycle through teammates and message
    them directly.

If the user answered "yes" to peer messaging, pass
`peer_messaging_active: true` to the pattern skill along with goal,
target, and preset context.
```

- [ ] **Step 4: Add prompt-fragment reference to all 5 pattern skills**

In each pattern skill's prompt construction section, add a new part after the
existing parts (typically after Part 3: Goal and Target Context):

```markdown
#### Part 4: Shared Prompt Fragments

Include the following fragments from
`$CLAUDE_PLUGIN_ROOT/config/prompt-fragments.md`:

- `human-interaction`
- `shutdown-protocol`
- `peer-roster` (only if peer_messaging is active)
```

Apply this to:

- `src/skills/swarm-fan-out/SKILL.md` (Step 6 prompt construction)
- `src/skills/swarm-pipeline/SKILL.md` (Step 7 prompt construction)
- `src/skills/swarm-swarm/SKILL.md` (Step 7 prompt construction)
- `src/skills/swarm-map-reduce/SKILL.md` (Step 7 — add Part 4 to BOTH the
  mapper prompt subsection AND the reducer prompt subsection separately)
- `src/skills/swarm-speculative/SKILL.md` (Step 7 — add Part 4 to BOTH the
  implementer prompt subsection AND the judge prompt subsection separately)

- [ ] **Step 5: Verify lints**

Run:

```bash
markdownlint-cli2 src/skills/swarm/SKILL.md \
  src/skills/swarm-fan-out/SKILL.md \
  src/skills/swarm-pipeline/SKILL.md \
  src/skills/swarm-swarm/SKILL.md \
  src/skills/swarm-map-reduce/SKILL.md \
  src/skills/swarm-speculative/SKILL.md
yq --exit-status 'tag == "!!map" or tag == "!!seq"' src/config/swarm-roles.yaml >/dev/null
```

Expected: 0 errors

- [ ] **Step 6: Commit**

```bash
git add src/config/swarm-roles.yaml \
  src/skills/swarm/SKILL.md \
  src/skills/swarm-fan-out/SKILL.md \
  src/skills/swarm-pipeline/SKILL.md \
  src/skills/swarm-swarm/SKILL.md \
  src/skills/swarm-map-reduce/SKILL.md \
  src/skills/swarm-speculative/SKILL.md
git commit -m "feat(ux): display mode hints, human interaction, confirmation template

Add display_mode preset field (tmux hint for best-of-three).
Add combined confirmation template with display-mode, peer-messaging,
and Shift+Down tip. Add prompt-fragment references to all pattern
skills for human-interaction and shutdown-protocol awareness."
```

---

## Chunk 3: Debate Pattern

### Task 6: Debate Pattern — Skill, Hooks, and Config

Create the debate orchestration skill, add hook support, and add the preset.
Depends on Tasks 1 and 5 (prompt library and confirmation template).

**Files:**

- Create: `src/skills/swarm-debate/SKILL.md`
- Modify: `src/hooks/scripts/lib/pattern-detect.sh` (add `debate`)
- Modify: `src/hooks/scripts/teammate-idle.sh` (add `debate` case)
- Modify: `src/config/swarm-roles.yaml` (add `code-debate` preset)
- Modify: `src/skills/swarm/SKILL.md` (add debate routing)

- [ ] **Step 1: Create swarm-debate/SKILL.md**

Create `src/skills/swarm-debate/SKILL.md`. Model the structure after
`src/skills/swarm-fan-out/SKILL.md` but with the debate-specific flow from the
spec. Key differences from fan-out:

Frontmatter:

```yaml
---
name: swarm-debate
description: >-
  Adversarial peer-to-peer review. Specialists analyze, then
  challenge each other's findings before reporting to the lead.
---
```

Checklist (11 steps):

```markdown
1. Identify goal and target
2. Select roles
3. Check for existing team
4. Confirm with user (include token-cost warning)
5. Create team and tasks
6. Spawn specialists
7. Monitor debate exchange
8. Collect final positions
9. Synthesize and present debate report
10. Await user instructions
11. Shutdown and cleanup
```

Step 4 confirmation must include: *"Debate pattern uses significantly more
tokens than fan-out due to peer messaging. Proceed?"*

Step 5 team naming: `swarm-debate-{goal-slug}-{timestamp}`

Step 6 prompt construction — each specialist gets:

- Part 1: Identity (same as fan-out)
- Part 2: Role prompt (from swarm-roles.yaml)
- Part 3: Goal and target
- Part 4: Shared prompt fragments (`human-interaction`, `shutdown-protocol`,
  `peer-roster`)
- Part 5: Debate protocol (from spec — the 5-step MUST instructions with
  2-round cap, dual SendMessage for rebuttals)

Step 7 (lead moderates): the lead monitors incoming messages. If an agent goes
idle without sending a final position, nudge. If exchange becomes circular (same
points repeated across messages), call time and request final positions.

Step 9 report structure: Consensus Findings, Revised Findings (with
original → revised), Unresolved Disagreements, Summary.

Shutdown: use per-agent structured shutdown from Task 3 (structured
messages cannot be broadcast).

- [ ] **Step 2: Verify debate skill lint**

Run: `markdownlint-cli2 src/skills/swarm-debate/SKILL.md`
Expected: 0 errors

- [ ] **Step 3: Edit pattern-detect.sh — add debate**

In `src/hooks/scripts/lib/pattern-detect.sh`, change line 15-16 from:

```bash
PATTERN_RE='^swarm-(fan-out|swarm|pipeline|task-graph'
PATTERN_RE+='|map-reduce|speculative)-'
```

to:

```bash
PATTERN_RE='^swarm-(fan-out|swarm|pipeline|task-graph'
PATTERN_RE+='|map-reduce|speculative|debate)-'
```

- [ ] **Step 4: Edit teammate-idle.sh — add debate case**

In `src/hooks/scripts/teammate-idle.sh`, add a new case before the `*)`
default in the `case "$PATTERN" in` block (before line 128):

```bash
  debate)
    # Two-stage gate: peer findings first, then final position to lead
    #
    # Known limitation: Stage 1 checks for ANY SendMessage, not
    # specifically messages to non-lead peers. A teammate who sends
    # only to the lead (skipping peer exchange) passes Stage 1.
    # Transcript JSON does not reliably expose the SendMessage
    # recipient in a grep-friendly format. This is an accepted
    # false-pass risk — the same heuristic approach used by other
    # patterns. Do not attempt a more complex grep; it won't work
    # reliably with transcript JSON structure.
    #
    # Stage 1: has the agent sent findings to anyone?
    if ! grep -qE '"name"\s*:\s*"SendMessage"' "$TRANSCRIPT_PATH" 2>/dev/null; then
      nudge_or_stop "$TEAMMATE_NAME: You haven't shared your initial findings with other specialists yet. Complete your analysis and send findings to all peers via SendMessage."
    fi
    # Stage 2: has the agent sent final position to the lead?
    if grep -qiE '"(final|position)"' "$TRANSCRIPT_PATH" 2>/dev/null; then
      exit 0
    fi
    nudge_or_stop "$TEAMMATE_NAME: You haven't sent your final position to the team lead yet. Consolidate your findings (including any peer challenges) and send your final position."
    ;;
```

- [ ] **Step 5: Verify shell lint**

Run:

```bash
shellcheck src/hooks/scripts/teammate-idle.sh
shellcheck src/hooks/scripts/lib/pattern-detect.sh
```

Expected: 0 errors (or only pre-existing warnings)

- [ ] **Step 6: Edit swarm-roles.yaml — add code-debate preset**

Add after the `monitored-review` preset:

```yaml
  code-debate:
    description: "Adversarial review — specialists challenge each other"
    pattern: debate
    display_mode: tmux
    roles: [security-reviewer, performance-reviewer, quality-reviewer]
```

- [ ] **Step 7: Verify YAML lint**

Run: `yq --exit-status 'tag == "!!map" or tag == "!!seq"' src/config/swarm-roles.yaml >/dev/null`
Expected: 0 errors

- [ ] **Step 8: Edit README.md — add debate pattern and preset**

In `README.md`, add a `### Debate` section after `### Swarm (Self-Claiming
Pool)` (after line 102):

```markdown
### Debate

Adversarial peer-to-peer review. Specialists analyze the same target, then
challenge each other's findings through structured rounds before reporting
final positions to the lead.

```text
> /swarm review src/auth/ with code-debate preset
```
```

In the `### Built-in Presets` table, add:

```markdown
| `code-debate`           | debate      | security, performance, quality (peer)    |
```

- [ ] **Step 9: Edit dispatcher SKILL.md — add debate routing**

In `src/skills/swarm/SKILL.md`, in the routing table (Step 6), add:

```markdown
| `debate` | `swarm-debate` |
```

- [ ] **Step 10: Verify README and dispatcher lint**

Run: `markdownlint-cli2 README.md src/skills/swarm/SKILL.md`
Expected: 0 errors

- [ ] **Step 11: Commit**

```bash
git add src/skills/swarm-debate/SKILL.md \
  src/hooks/scripts/lib/pattern-detect.sh \
  src/hooks/scripts/teammate-idle.sh \
  src/config/swarm-roles.yaml \
  src/skills/swarm/SKILL.md \
  README.md
git commit -m "feat(debate): add adversarial peer-to-peer review pattern

Specialists analyze, exchange findings, challenge disagreements
(2-round cap), then report final positions to the lead. Two-stage
idle hook distinguishes 'never sent peer findings' from 'no final
position'. Includes code-debate preset with tmux display hint."
```

---

## Chunk 4: Peer Messaging

### Task 7: Two-Gate Peer Messaging Flag

Add the preset-level enablement and per-invocation activation for peer
messaging. Depends on Tasks 1 and 5 (prompt library and confirmation template).

**Files:**

- Modify: `src/config/swarm-roles.yaml` (add `peer_messaging: allowed`)
- Modify: `src/skills/swarm-fan-out/SKILL.md` (conditional peer prompt)
- Modify: `src/skills/swarm-swarm/SKILL.md` (conditional peer prompt)
- Modify: `src/skills/swarm-speculative/SKILL.md` (conditional peer prompt)

- [ ] **Step 1: Edit swarm-roles.yaml — add peer_messaging to presets**

Add `peer_messaging: allowed` to `pr-review` and `full-review` presets:

```yaml
  pr-review:
    description: "Standard PR review with three specialists"
    pattern: fan-out
    peer_messaging: allowed
    roles: [security-reviewer, performance-reviewer, quality-reviewer]

  full-review:
    description: "Comprehensive review including architecture"
    pattern: fan-out
    peer_messaging: allowed
    roles:
      - security-reviewer
      - performance-reviewer
      - quality-reviewer
      - architecture-reviewer
```

- [ ] **Step 2: Verify YAML lint**

Run: `yq --exit-status 'tag == "!!map" or tag == "!!seq"' src/config/swarm-roles.yaml >/dev/null`
Expected: 0 errors

- [ ] **Step 3: Add conditional peer prompt to fan-out, swarm, speculative**

In each of these 3 pattern skills, in the prompt construction section, after the
Part 4 prompt-fragment reference (added in Task 5), add:

```markdown
#### Part 5: Peer Collaboration (conditional)

Include ONLY if `peer_messaging_active` is true (passed from the
dispatcher):

    ## Peer Collaboration (Optional)

    Other specialists on your team: {roster from peer-roster
    fragment}. You may message them directly via SendMessage if you
    discover findings relevant to their domain. This is optional —
    prioritize completing your own analysis and reporting to the
    lead. Peer messages are a bonus, not a requirement.

When `peer_messaging_active` is false or absent, skip this part
entirely — no roster, no peer instructions.
```

Apply to:

- `src/skills/swarm-fan-out/SKILL.md` (Step 6)
- `src/skills/swarm-swarm/SKILL.md` (Step 7)
- `src/skills/swarm-speculative/SKILL.md` (Step 7)

Do NOT add to pipeline or map-reduce (lead relay is structural). Do NOT add to
debate (peer messaging is inherent, not opt-in).

- [ ] **Step 4: Verify lints**

Run:

```bash
markdownlint-cli2 src/skills/swarm-fan-out/SKILL.md \
  src/skills/swarm-swarm/SKILL.md \
  src/skills/swarm-speculative/SKILL.md
```

Expected: 0 errors

- [ ] **Step 5: Commit**

```bash
git add src/config/swarm-roles.yaml \
  src/skills/swarm-fan-out/SKILL.md \
  src/skills/swarm-swarm/SKILL.md \
  src/skills/swarm-speculative/SKILL.md
git commit -m "feat(peer): two-gate peer messaging flag

Presets can declare peer_messaging: allowed (gate 1). Users opt in
per-invocation at dispatch time (gate 2, default no). When active,
teammates get a roster and lightweight peer collaboration prompt.
Enabled on pr-review and full-review presets."
```
