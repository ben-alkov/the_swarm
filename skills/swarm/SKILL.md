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
   `~/.claude/plugins/swarm/config/swarm-roles.yaml`.

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

6. **Watchdog modifier** — if the preset has `watchdog: true`,
   spawn an additional monitor agent alongside the pattern's
   normal agents:

   - Use the `monitor` role from `swarm-roles.yaml`
   - Spawn with `run_in_background: true`
   - The monitor observes via TaskList and sends alerts to the
     lead — it does not intervene directly
   - Spawn the monitor after the pattern skill creates the team
     (step 6 or equivalent in the pattern skill)
