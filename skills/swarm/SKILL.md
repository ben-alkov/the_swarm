---
name: swarm
description: >-
  Dispatch a swarm using any orchestration pattern. Routes to the
  appropriate pattern-specific skill based on the selected preset.
---

# Swarm Dispatcher

## Overview

Route swarm requests to the appropriate pattern skill. Read the
preset config, determine the pattern, and follow the corresponding
skill.

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

## Stale Worktree Cleanup

Before starting any swarm, check for leftover worktrees from
previous sessions:

```bash
git worktree list
```

If worktrees exist that are not associated with the current session
(stale branches from crashed or abandoned swarms), offer the user
two options:

1. **Remove stale worktrees**: `git worktree remove <path>` for
   each stale entry. This reclaims disk space but the branches
   persist and can still be merged.
2. **Keep them**: the user may want to inspect or recover work.

Only worktrees whose branch names match the `swarm-*` naming
convention should be flagged. Non-swarm worktrees are outside
this plugin's scope.

## Steps

1. **Identify goal and target** from the user's request. If unclear,
   ask.

2. **Read roles config** from
   `$CLAUDE_PLUGIN_ROOT/config/swarm-roles.yaml`.

3. **Select preset or roles** using the same priority as v1.
   When resolving roles, check for inline definitions in the preset
   first (entries with a `name` and `prompt` field), then fall back
   to global role names in the `roles:` section.
   - User specifies a preset name -> use it
   - User specifies individual role names -> use those (fan-out)
   - User describes what they want -> match to preset/roles
   - Default for "review" -> `pr-review` preset

4. **Determine pattern** from the selected preset's `pattern` field.
   If absent, default to `fan-out`. If the preset has
   `deprecated: true`, warn the user and suggest the `successor`
   preset instead. Proceed only if the user confirms.

5. **Route to pattern skill** — read and follow the corresponding
   skill:

   | Pattern | Skill |
   |---|---|
   | `fan-out` (or absent) | `swarm-fan-out` |
   | `swarm` | `swarm-swarm` |
   | `pipeline` | `swarm-pipeline` |
   | `task-graph` | `swarm-pipeline` |
   | `map-reduce` | `swarm-map-reduce` |
   | `speculative` | `swarm-speculative` |

   Read the skill file and follow its checklist from step 1.
   Pass through: goal, target, selected roles/preset, and any
   user context.

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
