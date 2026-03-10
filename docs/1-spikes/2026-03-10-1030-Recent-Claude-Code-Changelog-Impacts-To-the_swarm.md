---
Assess aligment of recent Claude Code changelog to the_swarm

Type: Spike
Date: 2026-03-10
Goal: Investigation of select recent Claude Code changelog impacts to the_swarm
Specialists: worktree/isolation, hooks/events, plugin/marketplace, skills/agents, new tools
---

<!-- markdownlint-disable ol-prefix first-line-h1 line-length -->

❯ /superpowers:using-superpowers Use the swarm. I have listed some bullet points
 from recent Claude Code changelogs. Please examine them, and investigate their
 impact on the_swarm in terms of implementation and function.

The bullet points span releases between 2.1.49 and 2.1.72, inclusive.

- Added ExitWorktree tool to leave an EnterWorktree session
- Added support for marketplace git URLs without .git suffix (Azure DevOps, AWS
  CodeCommit)
- Fixed team agents to inherit the leader's model
- Fixed worktree isolation issues: Task tool resume not restoring cwd, and
  background task notifications missing worktreePath and worktreeBranch
- Restored the model parameter on the Agent tool for per-invocation model
  overrides
- Added cron scheduling tools for recurring prompts within a session
- Fixed /plugin marketplace add owner/repo@ref incorrectly parsing @ —
  previously only # worked as a ref separator, causing undiagnosable errors with
  strictKnownMarketplaces
- Added plugin source type git-subdir to point to a subdirectory within a git
  repo
- Added InstructionsLoaded hook event that fires when CLAUDE.md or
  .claude/rules/*.md files are loaded into context
- Added ${CLAUDE_SKILL_DIR} variable for skills to reference their own directory
  in SKILL.md content
- Added agent_id (for subagents) and agent_type (for subagents and --agent) to
  hook events
- Fixed skill descriptions with colons (e.g., "Triggers include: X, Y, Z")
  failing to load from SKILL.md frontmatter
- Fixed TeammateIdle and TaskCompleted hooks to support {"continue": false,
  "stopReason": "..."} to stop the teammate, matching Stop hook behavior
- Added /simplify and /batch bundled slash commands
- Fixed slash command autocomplete crashing when a plugin's SKILL.md description
  is a YAML array or other non-string type
- Added WorktreeCreate and WorktreeRemove hook events, enabling custom VCS setup
  and teardown when agent worktree isolation creates or removes worktrees.
- Added support for isolation: worktree in agent definitions, allowing agents to
  declaratively run in isolated git worktrees
- Subagents support isolation: "worktree" for working in a temporary git
  worktree
- Ctrl+F keybinding to kill background agents (two-press confirmation)
- Agent definitions support background: true to always run as a background task
- Plugins can ship settings.json for default configuration

● Let me first read the key project files to understand current state, then
dispatch investigation agents in parallel.

● Good — I now have full context on the_swarm's implementation. Let me dispatch
parallel investigation agents, one per domain group.

● 5 agents launched (ctrl+o to expand)
   ├─ Investigate worktree/isolation changes
   │  ⎿  Running in the background
   ├─ Investigate hooks/events changes
   │  ⎿  Running in the background
   ├─ Investigate plugin/marketplace changes
   │  ⎿  Running in the background
   ├─ Investigate skills/agents changes
   │  ⎿  Running in the background
   └─ Investigate new tools/features
      ⎿  Running in the background

● Five investigation agents dispatched in parallel, grouped by domain:

┌───────┬────────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Agent │       Domain       │                                          Changelog Items                                          │
├───────┼────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────┤
│ 1     │ Worktree/Isolation │ ExitWorktree, worktree fixes, WorktreeCreate/Remove events, isolation: worktree support           │
├───────┼────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────┤
│ 2     │ Hooks/Events       │ InstructionsLoaded, agent_id/agent_type fields, stop-teammate support, WorktreeCreate/Remove      │
├───────┼────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────┤
│ 3     │ Plugin/Marketplace │ git URL suffix, @ ref parsing fix, git-subdir source type, settings.json                          │
├───────┼────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────┤
│ 4     │ Skills/Agents      │ model inheritance, model parameter, ${CLAUDE_SKILL_DIR}, colon fix, background: true, Ctrl+F kill │
├───────┼────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────┤
│ 5     │ New Tools          │ cron scheduling, /simplify, /batch                                                                │
└───────┴────────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────┘

---

## Changelog Impact Assessment: Claude Code v2.1.49–2.1.72 → the_swarm

### High Impact — Validates Core Design

These fixes make the_swarm's existing architecture work as intended, requiring
no code changes

┌───────────────────────────────────────────────────────────┬──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                           Item                            │                                                          Effect                                                          │
├───────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Team agents inherit leader's model                        │ the_swarm's two-tier model strategy (pin sonnet for reviewers, inherit parent for implementers/judges) now actually      │
│                                                           │ works. The swarm-roles.yaml comment was aspirational before; it's now accurate.                                          │
├───────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Restored model parameter on Agent tool                    │ The explicit model: sonnet overrides on reviewer/researcher roles take effect. Paired with inheritance fix above, both   │
│                                                           │ tiers work simultaneously.                                                                                               │
├───────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Worktree isolation bug fixes (cwd restore, missing        │ Speculative pattern agents that resume after crashes now restore to the correct working directory. Background task       │
│ worktreePath/worktreeBranch)                              │ notifications now carry branch info the lead needs for judging.                                                          │
└───────────────────────────────────────────────────────────┴──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

### High Impact — New Opportunities

These enable improvements the_swarm should adopt

1. Cron scheduling for the watchdog monitor The monitor's prompt says
  "periodically check TaskList" with no defined interval. Cron tools close this
  gap.

- File: src/skills/swarm/SKILL.md lines 178–188 (monitor spawn prompt)
- Change: Replace vague "periodically" with a cron-scheduled check (e.g., every
  60–120s)
- Also consider: src/config/swarm-roles.yaml monitor role prompt for consistency

2. `{"continue": false, "stopReason": "..."}` for hook escalation

  Currently hooks can only nudge (exit 2) or allow (exit 0). The new stop
  mechanism enables hard-stopping runaway agents after repeated failed nudges.

- Files: src/hooks/scripts/teammate-idle.sh, src/hooks/scripts/task-completed.sh
- Change: After N idle cycles on the same session, emit JSON {"continue": false,
  "stopReason": "..."} instead of exit 2
- Caveat: Verify from hooks docs whether JSON output replaces or supplements
  exit codes

3. `WorktreeCreate` / `WorktreeRemove` hook events

  The dispatcher's manual stale-worktree cleanup (git worktree list + user
  prompt) could be supplemented with automated hook-driven tracking.

- Files: src/hooks/hooks.json (add entries), new
  src/hooks/scripts/worktree-create.sh and worktree-remove.sh
- Change: Track swarm-* worktrees on creation, clean up on removal. The existing
  manual check in src/skills/swarm/SKILL.md lines 41–61 can remain as a
  fallback.

4. `background: true` in agent definitions

  All pattern skills repeat `run_in_background: true` on every spawn (~10–15
  occurrences). Declarative `background: true` in role definitions could eliminate
  this.

- Files: src/config/swarm-roles.yaml (add field to all roles), all six SKILL.md
  files (remove run_in_background from spawn blocks)
- Caveat: Verify whether `background: true` works in role config entries consumed
  by Task invocations, or only in Claude Code agent definition files

### Medium Impact — Incremental Improvements

┌─────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────────┬───────────────────────────────────────────┐
│          Item           │                                                     Effect                                                     │                  Action                   │
├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────┤
│ agent_id / agent_type   │ teammate-idle.sh currently constructs agent transcript paths from session_id — fragile. agent_id as a          │ Update both hook scripts to parse and use │
│ in hook events          │ first-class field could make this more reliable. agent_type could replace the name-based monitor exemption.    │  new fields                               │
├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────┤
│ git-subdir source type  │ Validates the_swarm's existing marketplace.json which already uses "source": "git-subdir". This was the        │ None — already correct                    │
│                         │ enabling feature for the src/ subdirectory layout.                                                             │                                           │
├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────┤
│ @ ref separator fix     │ Users can now install with ben-alkov/the_swarm@main instead of needing #.                                      │ Optional docs update                      │
├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───────────────────────────────────────────┤
│ settings.json for       │ Could expose user-overridable defaults (reviewer model, max agents, default pattern) without forking           │ Optional: create                          │
│ plugins                 │ swarm-roles.yaml.                                                                                              │ src/.claude-plugin/settings.json          │
└─────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴───────────────────────────────────────────┘

### No Impact

┌────────────────────────────────────────────────┬──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                      Item                      │                                                 Why                                                  │
├────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ ExitWorktree tool                              │ Lead never enters worktrees; agents use isolation: worktree parameter                                │
├────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ isolation: worktree in agent definitions       │ Already leveraged — the_swarm was built around this                                                  │
├────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Subagents support isolation: "worktree"        │ Same — already leveraged                                                                             │
├────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ ${CLAUDE_SKILL_DIR}                            │ Skills reference $CLAUDE_PLUGIN_ROOT/config/ which is cleaner than ${CLAUDE_SKILL_DIR}/../../config/ │
├────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Colon fix in SKILL.md descriptions             │ No descriptions contain colons; >- block scalars are immune regardless                               │
├────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Autocomplete crash for non-string descriptions │ All descriptions are already plain strings                                                           │
├────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ InstructionsLoaded hook event                  │ No current use case for the_swarm's architecture                                                     │
├────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ /simplify, /batch                              │ User-facing commands, not relevant to internal orchestration                                         │
├────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Ctrl+F kill for background agents              │ User escape hatch; compatible with existing shutdown protocol                                        │
├────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Git URL .git suffix support                    │ the_swarm uses shorthand owner/repo, not full URLs                                                   │
└────────────────────────────────────────────────┴──────────────────────────────────────────────────────────────────────────────────────────────────────┘

## Assumptions

- The model inheritance and parameter fixes are assumed to apply to Task tool
  invocations (which the_swarm uses), not just Agent tool calls
- `background: true` in "agent definitions" may refer to Claude Code's agent
  definition files rather than arbitrary role configs — needs verification
  before adopting
- The {"continue": false} hook output mechanism's exact interaction with exit
  codes needs verification from hooks docs

## Recommended Priority

1. Cron for monitor — closes the most visible design gap (undefined "periodic"
   interval)
2. Hook stop escalation — prevents infinite nudge loops on broken agents
3. WorktreeCreate/Remove hooks — replaces fragile prompt-driven cleanup with
   automation
4. `background: true` in roles — simplification across all skills, if the runtime
   supports it
5. agent_id/agent_type in hooks — robustness improvement for transcript
   resolution
6. settings.json — user ergonomics, lower priority
