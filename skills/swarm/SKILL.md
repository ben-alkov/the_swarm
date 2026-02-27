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

## Steps

1. **Identify goal and target** from the user's request. If unclear,
   ask.

2. **Read roles config** from
   `$CLAUDE_PLUGIN_ROOT/config/swarm-roles.yaml`.

3. **Select preset or roles** using the same priority as v1:
   - User specifies a preset name -> use it
   - User specifies individual role names -> use those (fan-out)
   - User describes what they want -> match to preset/roles
   - Default for "review" -> `pr-review` preset

4. **Determine pattern** from the selected preset's `pattern` field.
   If absent, default to `fan-out`.

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
