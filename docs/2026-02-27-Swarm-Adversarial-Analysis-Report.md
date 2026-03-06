---
Swarm Adversarial Analysis Report

Goal: Deep cross-cutting adversarial analysis of the_swarm plugin
Target: All files in /home/balkov/Source/the_swarm/
Specialists: state-machine, failure-modes, platform-friction, spec-drift, edge-cases, bug-validation

---

<!-- markdownlint-disable ol-prefix first-line-h1 line-length -->

## Critical Issues

1. Pipeline/Map-Reduce/Speculative: Blocked agents unblock before receiving
   upstream context (race condition)

   Found by: state-machine (C1, C3, C4), failure-modes (F3),
   platform-friction (PF5)

   Agents for downstream stages are spawned upfront with blocked tasks. When
   upstream tasks complete, the blocked task auto-unblocks — but the lead hasn't
   yet forwarded the upstream findings via SendMessage. The downstream agent claims
   its task and begins work without the context it needs. This silently breaks the
   core value proposition of sequential patterns (pipeline output-feeds-input,
   reducer needs mapper outputs, judge needs approach summaries).

   - Pipeline: Stage B agents start without Stage A findings
   - Map-Reduce: Reducer starts without mapper outputs
   - Speculative: Judge starts without approach summaries and branch names

   Fix: Either lazy-spawn downstream agents (only after relay), or restructure so
   agents wait for a "start" SendMessage from the lead before claiming their task.

2. Hook transcript grep is fragile and actively broken in production

   Found by: state-machine (live reproduction), failure-modes (F2, F9),
   platform-friction (PF4), spec-drift (cross-cutting obs. 1)

   The hooks check grep -q '"name": "SendMessage"' against a transcript file.
   Multiple failure modes

   - Live reproduction: state-machine analyst confirmed that after successfully
   calling SendMessage, the TaskCompleted hook still blocked task completion. The
   transcript path was either empty or the file didn't exist, causing the grep to
   fail → falls through to exit 2 (block).
   - String matching catches failed SendMessage calls (tool use record logged
   before result)
   - set -euo pipefail + jq parse errors = uncontrolled exit codes (neither 0 nor
   2)
   - Transcript format changes would silently disable all gates

   Fix: If transcript path is absent or file doesn't exist, fail open (exit 0). Use
   jq for semantic parsing instead of raw grep. Add stderr warnings when gates are
   bypassed.

2.1 Addendum to Critical #2: Root Cause Identified

   The failure-modes analyst pinpointed the exact bug before shutting down:

- teammate-idle.sh line 38 (working tree): grep -qE '"name"\s*:\s*"SendMessage"'
   — handles both compact and spaced JSON. Correct.
- task-completed.sh line 39 (working tree): grep -q '"name": "SendMessage"' —
   requires a space after the colon. Transcript JSON is compact
   ("name":"SendMessage"). Never matches.

   The fix applied to teammate-idle.sh was not carried over to task-completed.sh.

   Three lines in task-completed.sh (39, 49, 60) need grep -qE
   '"name"\s*:\s*"SendMessage"' to match the already-correct pattern in the other
   script.

   This is the most actionable finding from the entire analysis — a one-line fix in
   3 locations that unblocks all swarm task completions.

3. Config path assumption doesn't match plugin installation reality

   Found by: platform-friction (PF1), spec-drift (cross-cutting obs. 3)

   All skills hardcode ~/.claude/plugins/swarm/config/swarm-roles.yaml. The actual
   install path depends on installation method and could be
   ~/.claude/plugins/the_swarm/ or a versioned cache path. The lead reads a
   nonexistent file, gets no config, and either hallucinates roles or produces a
   confusing error.

   Fix: Use a relative path or platform-provided env variable ($CLAUDE_PLUGIN_ROOT)

4. Watchdog only implemented in fan-out — other patterns silently ignore
   watchdog: true

   Found by: state-machine (I2), failure-modes (F4), spec-drift (I1, S3),
   edge-cases (E6), bug-validation (Issue A)

   The dispatcher passes watchdog: true to any pattern skill, but only
   swarm-fan-out/SKILL.md has spawn instructions for the monitor. The other 4
   pattern skills mention the monitor in shutdown but have zero instructions for
   spawning it. The design doc says watchdog is a "modifier on any preset" —
   implementation only covers 1 of 5 patterns.

   Fix: Add a Watchdog Monitor spawn section to all pattern skills, or move monitor
   spawning responsibility to the dispatcher.

5. Degenerate configurations produce vacuous results silently

   Found by: edge-cases (E5, E13, E1)

   - approach_count: 1 in speculative → judge "picks" the only candidate, framing
   it as a comparison verdict
   - Zero workers with a reducer/judge → reducer/judge unblocks immediately with
   empty input, produces an empty "merged result" that appears successful
   - roles: [] → team created, no tasks, lead waits forever

   No pre-flight validation catches these configurations.

   Fix: Validate at config-read time: speculative requires approach_count >= 2,
   map-reduce requires at least 1 mapper + 1 chunk, all presets require at least 1
   role.

6. mode: "plan" parameter is unverified — plan approval may silently not work

   Found by: platform-friction (PF2), spec-drift (I3), bug-validation (Bug 3
   partial fix)

   The speculative skill uses mode: "plan" as a Task tool parameter with an inline
   hedge: "verify it exists before relying on it." The design doc references a
   different mechanism (CLAUDE_CODE_PLAN_MODE_REQUIRED env var). The fix added a
   disclaimer but didn't resolve which mechanism actually works. If neither works,
   plan_approval: true presets lose their safety gate silently.

   Fix: Test both mechanisms, pick the one that works, remove the hedge, document
   the verified behavior.

## Important Issues

1. Monitor agent has no task — hooks permanently block it, orphan risk after
   context compaction

   Found by: state-machine (C2, S3), failure-modes (F4), platform-friction (PF9)

   The monitor is spawned without a task. TeammateIdle fires for all swarm-*
   agents, sees no SendMessage (if no anomalies detected), and blocks the monitor
   indefinitely with nudge messages. After context compaction, the lead forgets the
   monitor exists → never sends shutdown_request → orphaned agent.

   Fix: Either give the monitor a task, add a hook exclusion for monitor agents
   ($TEAMMATE_NAME == "monitor"), or require the monitor to send a "monitoring
   started" message on spawn.

2. Speculative hooks can't distinguish implementers from judge — gate is too
   permissive

   Found by: state-machine (I1), failure-modes (F6)

   The speculative case checks for SendMessage OR git commit. An implementer that
   only sends a message (never commits) passes. A judge that only commits (never
   sends a verdict) passes. Both are wrong.

   Fix: Pattern-match $TEAMMATE_NAME: approach-* requires git commit; judge
   requires SendMessage.

3. Swarm worker self-claiming race condition — no atomic claim

   Found by: state-machine (S1), failure-modes (F5), platform-friction (PF8)

   Multiple workers call TaskList → both see the same pending task → both call
   TaskUpdate(owner: self). Last writer wins, first worker thinks it claimed a task
   it doesn't own. Could cause duplicate work or (with write-access workers)
   conflicting edits.

   Fix: Workers should verify claim success by re-checking TaskGet after TaskUpdate

4. Pipeline context relay is manual and unverified

   Found by: state-machine (I4), failure-modes (F3)

   The lead must manually forward stage N findings to stage N+1 agents. No
   enforcement, no confirmation, no timeout. Lead can forget, relay partial
   findings, or relay to wrong agents.

   Fix: Make relay a visible task in the task list, or require acknowledgment from
   downstream agents.

5. Map-reduce by-directory split has no cap — could spawn 50+ mappers

   Found by: platform-friction (PF10), edge-cases (E12)

   A repo with 50 top-level directories spawns 50 mappers. The design doc says 3-5
   is the sweet spot, but no skill enforces a cap.

   Fix: Add max_mappers cap (default 5-7). Batch directories when count exceeds cap

6. Missing role reference validation in non-fan-out patterns

   Found by: edge-cases (E7)

   Fan-out validates that referenced roles exist in config. Pipeline, swarm,
   map-reduce, and speculative do not — they'll proceed with nonexistent roles,
   producing empty or hallucinated prompts.

   Fix: All patterns should validate role references before spawning.

7. Isolation handling missing from swarm-swarm and map-reduce spawn steps

   Found by: edge-cases (E8)

   Fan-out and pipeline have explicit isolation handling (override Explore to
   general-purpose when isolation: worktree). Swarm-swarm and map-reduce lack this
   section. A custom worker_role with isolation: worktree would be spawned as
   Explore with a worktree — invalid combination.

   Fix: Add isolation handling to all pattern skills' spawn steps.

8. Goal slug generation not specified — special characters can break hooks

   Found by: edge-cases (E15)

   No rules for converting goal descriptions to team name slugs. Spaces, Unicode,
   slashes, very long strings, or embedded pattern names (e.g., "map-reduce
   docs") could break shell variable expansion or confuse the pattern-detect
   regex.

   Fix: Define slug rules: lowercase, alphanumeric + hyphens only, max 40 chars,
   truncate.

9. Shutdown assumes all agents alive — hangs on dead agents

   Found by: state-machine (S2), failure-modes (F12)

   Shutdown sends shutdown_request to each teammate and waits for
   shutdown_response. No timeout or fallback for crashed/terminated agents. Lead
   waits indefinitely.

   Fix: Add timeout guidance: "If no response after nudge, proceed with TeamDelete
   — the platform cleans up."

10. Session disconnect leaves orphaned teams with no recovery path

   Found by: failure-modes (F12), platform-friction (PF6)

   Session resume drops live teammates but the team and task list persist. No
   recovery procedure exists. Re-invoking the swarm hits "team already exists" with
   no way to recover partial work.

   Fix: Add a "resume existing swarm" recovery path: detect orphaned state, offer
   options (delete and restart, or synthesize from completed tasks).

## Suggestions

1. Single-agent fan-out (security-audit preset) is wasteful — orchestration
   overhead with no parallelism benefit. (edge-cases E2)
2. Single-stage pipeline degenerates to fan-out but uses pipeline hook semantics
   — warn users. (edge-cases E3)
3. Single-chunk map-reduce spawns an unnecessary reducer — bypass it.
   (edge-cases E4)
4. implement-and-review preset is a confusing anti-pattern — reviewer sees
   pre-change code. Description warns but it's buried. (state-machine I6,
   edge-cases E14)
5. Worktree directories accumulate across sessions — no cleanup mechanism for
   abrupt session ends. (platform-friction PF7)
6. No inline role definitions in presets — global namespace pollution for
   single-use roles. (edge-cases E11)
7. swarm-module-audit preset promoted from example to first-class without design
   doc update — scope creep. (spec-drift I5)
8. Reviewer roles pin model: sonnet without documentation — design doc shows no
   model field. (spec-drift I2)
9. Plan doc task completion status not tracked — future maintainers can't tell
   what's done. (spec-drift S6)
10. jq missing fails open with no warning — quality gates silently disappear.
    (failure-modes F1)

## Known Bug Fix Status

┌────────────────────────────┬─────────────────┬───────────────────────────────────────────────────────────────┐
│            Bug             │     Status      │                             Notes                             │
├────────────────────────────┼─────────────────┼───────────────────────────────────────────────────────────────┤
│ 1. Team naming             │ Fixed           │ fan-out segment now present in TeamCreate                     │
├────────────────────────────┼─────────────────┼───────────────────────────────────────────────────────────────┤
│ 2. Watchdog responsibility │ Fixed           │ Dispatcher explicitly delegates to pattern skills             │
├────────────────────────────┼─────────────────┼───────────────────────────────────────────────────────────────┤
│ 3. Plan approval mode      │ Partially fixed │ Disclaimer added but mechanism unresolved (Critical #6 above) │
├────────────────────────────┼─────────────────┼───────────────────────────────────────────────────────────────┤
│ 4. Task-graph asymmetry    │ Fixed           │ Documented in pipeline skill overview                         │
├────────────────────────────┼─────────────────┼───────────────────────────────────────────────────────────────┤
│ 5. worker_role docs        │ Fixed           │ Documented in swarm-swarm Step 2                              │
└────────────────────────────┴─────────────────┴───────────────────────────────────────────────────────────────┘

No regressions introduced by the fixes.

## Meta-Finding: The Swarm Ate Its Own Tail

The state-machine analyst's live reproduction of the TaskCompleted hook bug
(Critical #2) is a direct demonstration of the system's fragility — the swarm's
own quality gates prevented its analysts from completing their tasks. This is
the strongest possible validation that the hook transcript-grep approach needs
rework.

---

## Assumptions

- Platform behavior for TaskUpdate atomicity, SendMessage size limits, and mode:
  "plan" support is inferred from skill documentation, not tested
- Analysis is based on working-tree file state (including staged changes)
- "Critical" severity means the issue can cause silent incorrect behavior or
  deadlock under normal use

## Alternative Path

Rather than fixing each pattern skill individually (watchdog, isolation
handling, role validation, relay enforcement), consider extracting shared
behavior into the dispatcher or a shared preamble referenced by all pattern
skills. This trades skill file independence for consistency guarantees.
