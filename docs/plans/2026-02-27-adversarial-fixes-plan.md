<!-- markdownlint-disable line-length -->

# Adversarial Analysis Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to
> implement this plan task-by-task.

**Goal:** Fix all 16 critical/important issues from the adversarial analysis

**Architecture:** Markdown skill edits, Bash hook script fixes, YAML config
additions. No runtime code.

**Tech Stack:** Markdown, YAML, Bash

## Completion Status

- [x] Task 1: Fix hook transcript grep — fail-open + regex fix
- [x] Task 2: Fix speculative hooks — approach vs judge
- [x] Task 3: Add monitor agent exclusion to hooks
- [x] Task 4: Fix config path — use `$CLAUDE_PLUGIN_ROOT`
- [x] Task 5: Move watchdog spawning to dispatcher
- [x] Task 6: Add input validation to all pattern skills
- [x] Task 7: Add isolation handling to swarm and map-reduce
- [x] Task 8: Fix pipeline race — agents wait for lead start
- [x] Task 9: Fix map-reduce race — reducer waits for lead
- [x] Task 10: Fix speculative race — judge waits for lead
- [x] Task 11: Add swarm worker claim verification
- [x] Task 12: Add goal slug generation rules
- [x] Task 13: Add shutdown timeout guidance
- [x] Task 14: Add session recovery guidance
- [x] Task 15: Resolve plan approval parameter uncertainty
- [x] Task 16: Fix pipeline context relay

---

### Task 1: Fix hook transcript grep — fail-open on missing transcript + regex fix

**Files:**

- Modify: `hooks/scripts/teammate-idle.sh:33-69`
- Modify: `hooks/scripts/task-completed.sh:35-72`

**Step 1: Fix `teammate-idle.sh` — add fail-open for missing transcript**

In `teammate-idle.sh`, before the `case` statement (after line 31), add an
early-exit guard so a missing or unreadable transcript fails open instead of
falling through to `exit 2`:

```bash
# Fail open if transcript is unavailable — cannot verify, should not block
if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi
```

Then simplify each case branch: remove the outer
`if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]` guard (now
redundant) so the grep runs directly.

**Step 2: Fix `task-completed.sh` — same fail-open guard + grep regex fix**

Same pattern as step 1. Add the early-exit guard before the `case` statement.

Remove the outer transcript-existence checks from each case branch.

The grep patterns in `task-completed.sh` should already use
`grep -qE '"name"\s*:\s*"SendMessage"'` (flexible spacing). Verify all three
case branches (lines 40, 51, 63) use the `-qE` flag with `\s*` — if any
still use the rigid `'"name": "SendMessage"'` form, update them.

**Step 3: Verify both scripts pass `bash -n`**

Run: `bash -n hooks/scripts/teammate-idle.sh && bash -n hooks/scripts/task-completed.sh`
Expected: no output (syntax OK)

**Step 4: Commit**

```bash
git add hooks/scripts/teammate-idle.sh hooks/scripts/task-completed.sh
git commit -m "fix(hooks): fail-open on missing transcript, normalize grep patterns"
```

---

### Task 2: Fix speculative hooks — distinguish approach agents from judge

**Files:**

- Modify: `hooks/scripts/teammate-idle.sh:57-69`
- Modify: `hooks/scripts/task-completed.sh:59-71`

**Step 1: Replace the speculative case in `teammate-idle.sh`**

Replace the `speculative)` case with role-aware logic:

```bash
  speculative)
    # Approach agents must commit; judge must SendMessage
    if [[ "$TEAMMATE_NAME" == judge ]]; then
      if grep -qE '"name"\s*:\s*"SendMessage"' "$TRANSCRIPT_PATH" 2>/dev/null; then
        exit 0
      fi
      echo "$TEAMMATE_NAME: You haven't sent your verdict to the team lead yet." >&2
      exit 2
    else
      # Approach agents (approach-1, approach-2, etc.)
      if grep -q '"git commit"' "$TRANSCRIPT_PATH" 2>/dev/null; then
        exit 0
      fi
      echo "$TEAMMATE_NAME: You haven't committed your approach yet." >&2
      exit 2
    fi
    ;;
```

Remove the "accepted design limitation" comment — this removes the
limitation.

**Step 2: Same change in `task-completed.sh`**

Mirror the same role-aware logic in the `speculative)` case. Adjust the
feedback messages to reference task completion instead of idle.

**Step 3: Verify both scripts pass `bash -n`**

Run: `bash -n hooks/scripts/teammate-idle.sh && bash -n hooks/scripts/task-completed.sh`

**Step 4: Commit**

```bash
git add hooks/scripts/teammate-idle.sh hooks/scripts/task-completed.sh
git commit -m "fix(hooks): distinguish approach agents from judge in speculative gate"
```

---

### Task 3: Add monitor agent exclusion to hooks

**Files:**

- Modify: `hooks/scripts/teammate-idle.sh` (after the `swarm-` team check,
  before the case statement)
- Modify: `hooks/scripts/task-completed.sh` (same location)

**Step 1: Add monitor exclusion to `teammate-idle.sh`**

After the `source pattern-detect.sh` line, before the `case` statement, add:

```bash
# Monitor agents are exempt from quality gates — they observe, not produce
if [[ "$TEAMMATE_NAME" == "monitor" ]]; then
  exit 0
fi
```

**Step 2: Same in `task-completed.sh`**

Same monitor exclusion in the same location.

**Step 3: Verify both scripts pass `bash -n`**

Run: `bash -n hooks/scripts/teammate-idle.sh && bash -n hooks/scripts/task-completed.sh`

**Step 4: Commit**

```bash
git add hooks/scripts/teammate-idle.sh hooks/scripts/task-completed.sh
git commit -m "fix(hooks): exempt monitor agent from quality gates"
```

---

### Task 4: Fix config path — use `$CLAUDE_PLUGIN_ROOT` in all skills

**Files:**

- Modify: `skills/swarm/SKILL.md:22`
- Modify: `skills/swarm-fan-out/SKILL.md:66`
- Modify: `skills/swarm-pipeline/SKILL.md:71`
- Modify: `skills/swarm-map-reduce/SKILL.md:69`
- Modify: `skills/swarm-speculative/SKILL.md:70`
- Modify: `skills/swarm-swarm/SKILL.md:67`

**Step 1: Replace config path in all 6 skills**

In each file, replace:

```markdown
~/.claude/plugins/swarm/config/swarm-roles.yaml
```

with:

```markdown
$CLAUDE_PLUGIN_ROOT/config/swarm-roles.yaml
```

(Note: the `$CLAUDE_PLUGIN_ROOT` env var is already used in `hooks.json`,
confirming it is available in the plugin context.)

**Step 2: Commit**

```bash
git add skills/*/SKILL.md
git commit -m "fix(skill): use CLAUDE_PLUGIN_ROOT for config path"
```

---

### Task 5: Move watchdog spawning to the dispatcher

**Files:**

- Modify: `skills/swarm/SKILL.md:49-53` (replace current step 6)
- Modify: `skills/swarm-fan-out/SKILL.md:195-208` (remove Watchdog Monitor
  subsection from step 6)

**Step 1: Expand the dispatcher's watchdog section**

Replace `skills/swarm/SKILL.md` step 6 (lines 49-53) with a full watchdog
spawn procedure:

```markdown
6. **Watchdog modifier** — if the preset has `watchdog: true`, spawn one
   monitor agent using the `monitor` role from
   `$CLAUDE_PLUGIN_ROOT/config/swarm-roles.yaml` BEFORE routing to the
   pattern skill:

   - `team_name`: the team name (created by the pattern skill in its
     step 5/6 — spawn the monitor immediately after team creation,
     before specialist agents)
   - `name`: `monitor`
   - `subagent_type`: from the monitor role config (typically `Explore`)
   - `run_in_background`: `true`
   - `prompt`: include team name, goal, and instructions to:
     - Send a "Monitoring started — no anomalies detected yet" message
       to the team lead via SendMessage immediately on spawn
     - Periodically check TaskList for anomalies (stuck tasks, idle
       workers without findings)
     - Send alerts to the team lead via SendMessage when anomalies
       are detected
     - Do not intervene directly — report to the lead for decisions

   The dispatcher owns monitor lifecycle. Pattern skills do NOT spawn
   the monitor — they include it in their shutdown sequence.
```

**Step 2: Remove the Watchdog Monitor subsection from `swarm-fan-out`**

Delete the "Watchdog Monitor" subsection from step 6 (lines 195-208) of
`skills/swarm-fan-out/SKILL.md`. Leave the rest of step 6 intact.

**Step 3: Update dispatcher step 6 ordering note**

Add a note that the dispatcher should spawn the monitor after the pattern
skill creates the team but before the pattern skill spawns specialist agents.
The practical flow is:

1. Dispatcher routes to pattern skill
2. Pattern skill creates team (step 5/6)
3. Dispatcher spawns monitor into that team
4. Pattern skill spawns specialists (step 6/7)

Since the dispatcher hands off to the pattern skill, restructure as:
the dispatcher instructs the pattern skill to create the team and report
the team name back, then the dispatcher spawns the monitor, then tells
the pattern skill to continue with spawning.

Actually, simpler: the dispatcher adds to its "pass-through" data a note
that `watchdog: true` is active, and instructs the lead to spawn the monitor
immediately after team creation in whatever pattern skill it routes to. The
monitor spawn instructions live in the dispatcher (single source of truth)
but the lead executes them at the right moment during pattern execution.

Revise step 6 to say:

```markdown
6. **Watchdog modifier** — if the preset has `watchdog: true`, the lead
   must spawn a monitor agent immediately after creating the team (the
   pattern skill's "Create Team" step). Spawn it BEFORE spawning any
   specialist/worker agents.

   Use the `monitor` role from
   `$CLAUDE_PLUGIN_ROOT/config/swarm-roles.yaml`:

   - `name`: `monitor`
   - `subagent_type`: from the monitor role config (typically `Explore`)
   - `run_in_background`: `true`
   - `prompt`:
     - Identity: "Your name is monitor. You are part of team {team_name}."
     - Immediately send a "Monitoring started" message to the team lead
       via SendMessage (this satisfies the idle hook gate)
     - Periodically check TaskList for anomalies (stuck tasks, idle
       workers without findings)
     - Send alerts to the team lead via SendMessage when anomalies are
       detected
     - Do not intervene directly — report to the lead

   The monitor does not get its own task — it observes and reports.
   Include the monitor in shutdown (send `shutdown_request` to it).

   Pattern skills do NOT spawn the monitor. This section is the single
   source of truth for monitor spawning.
```

**Step 4: Update all pattern skills' shutdown steps**

In each pattern skill's shutdown step, the existing text says "include the
monitor agent if `watchdog: true` was active" — this is already correct and
needs no change. Verify each file has this clause:

- `swarm-fan-out/SKILL.md` step 10 (line 275)
- `swarm-swarm/SKILL.md` step 11 (line 252)
- `swarm-pipeline/SKILL.md` step 12 (line 315)
- `swarm-map-reduce/SKILL.md` step 12 (line 333)
- `swarm-speculative/SKILL.md` step 13 (line 391)

**Step 5: Commit**

```bash
git add skills/swarm/SKILL.md skills/swarm-fan-out/SKILL.md
git commit -m "fix(skill): centralize watchdog spawning in dispatcher"
```

---

### Task 6: Add input validation to all pattern skills

**Files:**

- Modify: `skills/swarm-fan-out/SKILL.md` (after step 2, before step 3)
- Modify: `skills/swarm-swarm/SKILL.md` (after step 2)
- Modify: `skills/swarm-pipeline/SKILL.md` (after step 2)
- Modify: `skills/swarm-map-reduce/SKILL.md` (after step 2)
- Modify: `skills/swarm-speculative/SKILL.md` (after step 2)

**Step 1: Add validation section to `swarm-fan-out`**

After step 2 "Select Roles", add a validation gate:

```markdown
### Validation

Before proceeding, validate the config:

- **Roles exist**: every role name in the preset's `roles` list must
  exist in the `roles:` section of the config. If any are missing,
  report the error to the user and abort.
- **Non-empty roles**: the `roles` list must contain at least 1 entry.
  If empty or missing, report the error and abort.
- **No duplicates**: warn the user if the same role appears more than
  once in the list.
```

**Step 2: Add validation to `swarm-speculative`**

After step 2 "Read Config", add:

```markdown
### Validation

Before proceeding, validate the config:

- **Minimum approaches**: `approach_count` must be >= 2. A single
  approach has no comparison value — report the error and abort.
- **Roles exist**: `approach_role` and `judge_role` must exist in the
  `roles:` section. If missing, report the error and abort.
```

**Step 3: Add validation to `swarm-map-reduce`**

After step 2 "Read Config", add:

```markdown
### Validation

Before proceeding, validate the config:

- **Roles exist**: `map_role` and `reduce_role` must exist in the
  `roles:` section. If missing, report the error and abort.
```

After step 3 "Determine the Split", add:

```markdown
### Split Validation

- **Minimum chunks**: the split must produce at least 1 chunk. If the
  target is empty or the split yields 0 chunks, report the error and
  abort.
- **Single chunk bypass**: if the split yields exactly 1 chunk, warn
  the user that map-reduce overhead is unnecessary and offer to run
  as a simple fan-out instead.
- **Maximum mappers**: if the split yields more than 7 chunks, warn
  the user that large swarms may hit context limits. Offer to batch
  directories into groups to reduce mapper count.
```

**Step 4: Add validation to `swarm-pipeline`**

After step 2 "Read Config", add:

```markdown
### Validation

Before proceeding, validate the config:

- **Non-empty topology**: pipeline must have at least 1 stage; task
  graph must have at least 1 node. If empty, report the error and
  abort.
- **Single-stage warning**: if a pipeline has exactly 1 stage, warn
  the user that this degenerates to fan-out and offer the simpler
  pattern.
- **Roles exist**: every role referenced in `stages[].roles` or
  `nodes[].role` must exist in the `roles:` section. If missing,
  report the error and abort.
- **No cycles** (task-graph): validate that `depends_on` references
  do not create cycles. If cycles found, report the error and abort.
- **Valid depends_on** (task-graph): all `depends_on` entries must
  reference existing node names.
```

**Step 5: Add validation to `swarm-swarm`**

After step 2 "Read Config", add:

```markdown
### Validation

Before proceeding, validate the config:

- **Role exists**: `worker_role` must exist in the `roles:` section.
  If missing, report the error and abort.
- **Scale warning**: if `worker_count` > 7, warn the user that large
  swarms may hit context limits and recommend 3-5 workers.
```

**Step 6: Commit**

```bash
git add skills/*/SKILL.md
git commit -m "fix(skill): add input validation to all pattern skills"
```

---

### Task 7: Add isolation handling to swarm-swarm and map-reduce

**Files:**

- Modify: `skills/swarm-swarm/SKILL.md` (step 7, before Prompt Construction)
- Modify: `skills/swarm-map-reduce/SKILL.md` (step 7, before mapper Prompt
  Construction)

**Step 1: Add isolation handling to `swarm-swarm`**

In step 7 "Spawn Workers" (after the bullet list of Task parameters, before
"Prompt Construction"), add:

```markdown
### Isolation Handling

Before spawning, check the worker role's `isolation` field:

- If `isolation: worktree` is set:
  - Override `subagent_type` to `general-purpose`
  - Print a note: `Role {name}: using general-purpose (worktree
    isolation requires write access)`
  - Pass `isolation: "worktree"` to the `Task` tool call
- If `isolation` is absent: use the role's `subagent_type` as-is
```

**Step 2: Add isolation handling to `swarm-map-reduce`**

In step 7 "Spawn Mappers and Reducer", under "Spawn Mappers" (after the
bullet list, before "Mapper Prompt Construction"), add the same isolation
handling section.

**Step 3: Commit**

```bash
git add skills/swarm-swarm/SKILL.md skills/swarm-map-reduce/SKILL.md
git commit -m "fix(skill): add isolation handling to swarm and map-reduce patterns"
```

---

### Task 8: Fix pipeline race — agents wait for lead's start message

**Files:**

- Modify: `skills/swarm-pipeline/SKILL.md:191-231` (step 7, prompt
  construction)
- Modify: `skills/swarm-pipeline/SKILL.md:233-252` (step 8, relay)

**Step 1: Update pipeline agent prompt — wait for start message**

In step 7, Part 1 "Identity and Stage Instructions" (lines 193-208),
replace the blocked-task instruction:

```markdown
Your task may be blocked by earlier stages. If your task is
blocked, wait — it will unblock automatically when dependencies
complete.
```

with:

```markdown
Your task may be blocked by earlier stages. When it unblocks, do
NOT claim it immediately. Wait for the team lead to send you a
"start" message via SendMessage containing upstream findings.
Only claim your task and begin work AFTER receiving the lead's
start message.

First-stage agents (no blockers): claim your task immediately.
```

**Step 2: Update step 8 — make relay explicit and require acknowledgment**

Replace step 8 (lines 233-252) with:

```markdown
## Step 8: Relay Context Between Stages

This is the lead's core responsibility in pipeline orchestration.

When a stage completes (all its tasks are done and agents have
sent findings):

1. Collect all findings from that stage's agents
2. Create a relay task via `TaskCreate`:
   - `subject`: "Relay stage {N} findings to stage {N+1}"
   - `description`: summary of what to forward
   - `activeForm`: "Relaying stage findings"
   - `addBlockedBy`: all task IDs from the completed stage
3. Forward the findings to the next stage's agents via
   `SendMessage` — include the stage name and a summary of what
   was done. End the message with: "You may now claim your task
   and begin work."
4. Wait for each downstream agent to acknowledge receipt via
   `SendMessage` before marking the relay task completed
5. Mark the relay task as completed

Do NOT proceed to the next relay until downstream agents have
acknowledged. If an agent does not acknowledge, nudge it.

### Context Passing Mechanisms

- **SendMessage relay** (default): lead forwards findings between
  stages as messages
- **Worktree chain** (when roles have `isolation: worktree`): each
  stage works on the branch from the previous stage. The lead
  includes the branch name in the forwarded context so the next
  stage can check it out.
```

**Step 3: Commit**

```bash
git add skills/swarm-pipeline/SKILL.md
git commit -m "fix(skill): pipeline agents wait for lead start message before claiming"
```

---

### Task 9: Fix map-reduce race — reducer waits for lead's forwarded data

**Files:**

- Modify: `skills/swarm-map-reduce/SKILL.md:225-261` (step 7, reducer
  prompt)

**Step 1: Update reducer prompt — wait for lead's forwarding message**

In step 7, Part 1 "Reducer Identity and Instructions" (lines 228-242),
replace the instructions with:

```markdown
Your name is reducer. You are part of team {team_name}.

You are the reducer in a map-reduce operation with {N} mappers.

Instructions:
- Your task is blocked until all mappers complete. When it unblocks,
  do NOT claim it immediately.
- Wait for the team lead to forward all mapper outputs to you via
  SendMessage. The lead's message will end with: "You may now claim
  your task and begin reducing."
- Only claim your task and mark it in_progress AFTER receiving all
  mapper outputs from the lead.
- Merge the mapper outputs into a unified result.
- Send your merged result to the team lead via SendMessage.
- Include a summary field in your message (5-10 words).
- Mark the task as completed.
```

**Step 2: Update step 9 — add explicit "you may now begin" sentinel**

In step 9 "Forward to Reducer" (lines 279-291), after "Send all mapper
outputs to the reducer via SendMessage", add:

```markdown
4. End the message with: "You may now claim your task and begin
   reducing."
5. Wait for the reducer to acknowledge receipt before proceeding
```

**Step 3: Add failed mapper recovery to step 8**

In step 8 "Collect Mapper Findings" (lines 263-277), under the "No
response after nudge" bullet, add:

```markdown
- Unresponsive mapper blocking reducer: manually mark the failed
  mapper's task as completed (or deleted) to unblock the reducer.
  Note the missing chunk in the forwarded data.
```

**Step 4: Commit**

```bash
git add skills/swarm-map-reduce/SKILL.md
git commit -m "fix(skill): reducer waits for lead forwarding before claiming task"
```

---

### Task 10: Fix speculative race — judge waits for lead's forwarded data

**Files:**

- Modify: `skills/swarm-speculative/SKILL.md:235-283` (step 7, judge prompt)

**Step 1: Update judge prompt — wait for lead's forwarding message**

In step 7, Part 1 "Judge Identity and Instructions" (lines 237-257),
replace the instructions with:

```markdown
Your name is judge. You are part of team {team_name}.

You are the judge in a speculative execution with {N} competing
approaches.

Instructions:
- Your task is blocked until all approaches complete. When it
  unblocks, do NOT claim it immediately.
- Wait for the team lead to forward all approach summaries and
  branch names to you via SendMessage. The lead's message will end
  with: "You may now claim your task and begin evaluating."
- Only claim your task and mark it in_progress AFTER receiving all
  approach reports from the lead.
- Evaluate each approach:
  - Check out each approach branch
  - Run tests and verify correctness
  - Evaluate code quality, maintainability, and completeness
- Select the best approach with clear justification
- Send your verdict to the team lead via SendMessage:
  - Include a summary field (5-10 words)
  - Include the winning branch name
  - Explain why you chose it and what the others lacked
- Mark the task as completed
```

**Step 2: Update step 10 — add sentinel and acknowledgment**

In step 10 "Forward to Judge" (lines 323-334), after "Send all approach
summaries + branch names to the judge via SendMessage", add:

```markdown
4. End the message with: "You may now claim your task and begin
   evaluating."
5. Wait for the judge to acknowledge receipt before proceeding
```

**Step 3: Commit**

```bash
git add skills/swarm-speculative/SKILL.md
git commit -m "fix(skill): judge waits for lead forwarding before claiming task"
```

---

### Task 11: Add swarm worker claim verification

**Files:**

- Modify: `skills/swarm-swarm/SKILL.md:155-192` (step 7, prompt
  construction)

**Step 1: Update worker loop instructions**

In step 7, Part 1 "Identity and Loop Instructions" (lines 159-173),
replace the worker loop with:

```markdown
You are a pool worker. Your workflow is a loop:

1. Check TaskList for unclaimed tasks (status: pending, no owner)
2. Claim one by setting yourself as owner and marking it in_progress
3. Verify the claim: call TaskGet on the task you claimed. If the
   owner is not your name, another worker claimed it first — go back
   to step 1
4. Complete the work described in the task
5. Send your findings to the team lead via SendMessage
   - Include a summary field (5-10 words)
   - Include the task subject in your message
6. Mark the task as completed
7. Go back to step 1

When no unclaimed tasks remain, go idle.
```

**Step 2: Commit**

```bash
git add skills/swarm-swarm/SKILL.md
git commit -m "fix(skill): add claim verification to swarm worker loop"
```

---

### Task 12: Add goal slug generation rules to dispatcher

**Files:**

- Modify: `skills/swarm/SKILL.md` (add new step between current steps 4
  and 5, or add as a subsection of step 5)

**Step 1: Add slug generation rules**

After step 4 "Determine pattern" and before step 5 "Route to pattern
skill", add a new subsection (or append to step 4):

```markdown
### Goal Slug Generation

When pattern skills create team names, they use the format
`swarm-{pattern}-{goal-slug}-{timestamp}`. Generate the goal slug
from the user's goal description:

- Lowercase only
- Replace spaces and special characters with hyphens
- Remove all characters except `a-z`, `0-9`, and `-`
- Collapse consecutive hyphens into one
- Truncate to 30 characters maximum
- Strip leading and trailing hyphens

Examples:
- "PR review" → `pr-review`
- "Security audit of auth module" → `security-audit-of-auth-module`
- "Fix the OAuth2/OIDC integration!!!" → `fix-the-oauth2-oidc-integrat`

Pass the goal slug through to the pattern skill along with the
goal, target, and preset.
```

**Step 2: Commit**

```bash
git add skills/swarm/SKILL.md
git commit -m "fix(skill): define goal slug generation rules in dispatcher"
```

---

### Task 13: Add shutdown timeout guidance to all pattern skills

**Files:**

- Modify: `skills/swarm-fan-out/SKILL.md:270-277` (step 10)
- Modify: `skills/swarm-swarm/SKILL.md:248-254` (step 11)
- Modify: `skills/swarm-pipeline/SKILL.md:310-317` (step 12)
- Modify: `skills/swarm-map-reduce/SKILL.md:328-335` (step 12)
- Modify: `skills/swarm-speculative/SKILL.md:386-396` (step 13)

**Step 1: Update shutdown in all 5 pattern skills**

In each skill's shutdown step, replace:

```markdown
1. Send `shutdown_request` to each teammate/agent/worker via `SendMessage`
   (include the monitor agent if `watchdog: true` was active)
2. Wait for `shutdown_response` from each
3. Call `TeamDelete` to clean up
```

with:

```markdown
1. Send `shutdown_request` to each teammate via `SendMessage`
   (include the monitor agent if `watchdog: true` was active)
2. Wait for `shutdown_response` from each. If an agent does not
   respond after a reasonable wait, send one nudge message. If
   still unresponsive, proceed — the agent may have crashed or
   terminated.
3. Call `TeamDelete` to clean up. `TeamDelete` is the authoritative
   cleanup mechanism — it will fail if active agents remain. If
   it fails, retry after unresponsive agents have timed out.
```

**Step 2: Commit**

```bash
git add skills/*/SKILL.md
git commit -m "fix(skill): add shutdown timeout guidance to all patterns"
```

---

### Task 14: Add session recovery guidance to all pattern skills

**Files:**

- Modify: `skills/swarm-fan-out/SKILL.md:80-86` (step 3)
- Modify: `skills/swarm-swarm/SKILL.md:89-95` (step 4)
- Modify: `skills/swarm-pipeline/SKILL.md:105-108` (step 4)
- Modify: `skills/swarm-map-reduce/SKILL.md:100-104` (step 4)
- Modify: `skills/swarm-speculative/SKILL.md:96-99` (step 4)

**Step 1: Expand "Check for Existing Team" in all 5 pattern skills**

In each skill's "Check for Existing Team" step, replace the current text
with:

```markdown
Only one team can exist per session. Before creating a new team,
check if one already exists.

If a team exists:

- **Active swarm**: warn the user that a swarm is already running
  and offer to shut it down first (`TeamDelete`).
- **Orphaned team** (from a crashed session or `/resume`): agents
  from the previous session are gone but the team and task list
  persist. Offer the user two options:
  1. **Delete and restart**: `TeamDelete` the orphaned team, then
     proceed with a fresh swarm.
  2. **Salvage completed work**: check `TaskList` for completed
     tasks, synthesize any available findings from completed tasks,
     then `TeamDelete` and optionally re-run incomplete tasks.
```

**Step 2: Commit**

```bash
git add skills/*/SKILL.md
git commit -m "fix(skill): add orphaned team recovery to all patterns"
```

---

### Task 15: Resolve plan approval parameter uncertainty

**Files:**

- Modify: `skills/swarm-speculative/SKILL.md:172-174` (step 7, mode
  parameter)
- Modify: `skills/swarm-speculative/SKILL.md:285-301` (step 8)

**Step 1: Verify which mechanism works**

Check the Claude Code Task tool documentation (the tool description in the
system prompt) for the `mode` parameter. The Task tool accepts a `mode`
parameter with enum values including `"plan"`. This is the correct
mechanism.

**Step 2: Remove the hedge from step 7**

In step 7, replace lines 172-174:

```markdown
- `mode`: `"plan"` if `plan_approval: true`, omit otherwise
  (this is the Task tool's `mode` parameter — verify it exists
  before relying on it for plan-approval gating)
```

with:

```markdown
- `mode`: `"plan"` if `plan_approval: true`, omit otherwise
```

**Step 3: Commit**

```bash
git add skills/swarm-speculative/SKILL.md
git commit -m "fix(skill): remove plan approval parameter hedge"
```

---

### Task 16: Fix pipeline context relay — add relay task + acknowledgment

This task is partially covered by Task 8 (the agent-side changes). This
task covers adding relay tasks to the task list for visibility.

**Files:**

- Modify: `skills/swarm-pipeline/SKILL.md:147-163` (step 6, Create Tasks)

**Step 1: Add relay tasks to step 6**

After the "Create Tasks" section in step 6, add:

```markdown
**Relay tasks** — one per stage transition via `TaskCreate`:

- `subject`: "Relay stage {N} findings to stage {N+1}"
- `description`: "Collect findings from stage {N} agents, forward
  to stage {N+1} agents via SendMessage, wait for acknowledgment"
- `activeForm`: "Relaying stage {N} findings"
- `addBlockedBy`: all task IDs from stage N — relay auto-unblocks
  when the source stage completes
- Relay tasks for stage N+1 should be added to the `addBlockedBy`
  list of stage N+1's agent tasks (in addition to stage N's tasks)

This makes relay a visible, trackable step in the task list. The
lead claims and completes relay tasks as part of step 8.
```

**Step 2: Commit**

```bash
git add skills/swarm-pipeline/SKILL.md
git commit -m "fix(skill): add relay tasks to pipeline for visible context passing"
```

---

## Task Dependency Summary

Tasks 1-3 modify hooks — do them first and sequentially (each builds on
the previous).

Tasks 4-16 modify skills/config — mostly independent. Task 8 and 16 both
modify `swarm-pipeline/SKILL.md` so do them together or sequentially.

```text
Task 1 (hook fix) → Task 2 (speculative hooks) → Task 3 (monitor exclusion)
Task 4 (config path) — independent
Task 5 (watchdog centralize) — independent
Task 6 (validation) — independent
Task 7 (isolation handling) — independent
Task 8 (pipeline race) → Task 16 (relay tasks) — sequential, same file
Task 9 (map-reduce race) — independent
Task 10 (speculative race) — independent
Task 11 (swarm claim) — independent
Task 12 (slug rules) — independent
Task 13 (shutdown timeout) — independent
Task 14 (session recovery) — independent
Task 15 (plan approval) — independent
```
