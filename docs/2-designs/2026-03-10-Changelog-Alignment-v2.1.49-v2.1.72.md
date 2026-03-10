---
Claude Code Changelog Alignment (v2.1.49-v2.1.72)

Type: Design
Date: 2026-03-10
Goal: Implement actionable findings from the changelog impact spike
Specialists: hooks/events, plugin/settings, skills/agents, tools/rename

---

<!-- markdownlint-disable ol-prefix first-line-h1 -->

## Context

The spike at
`docs/1-spikes/2026-03-10-1030-Recent-Claude-Code-Changelog-Impacts-To-the_swarm.md`
assessed recent Claude Code changelog items against the_swarm. This design
implements the 6 actionable findings, incorporating upstream verification
results.

### Verified Assumptions

| Assumption                                | Result                                                                                                       |
|-------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| Hook JSON `{"continue": false}`           | Exit 0 + JSON stdout. Alternative to exit 2, not combined. Both TeammateIdle and TaskCompleted support it.   |
| `background: true` in role configs        | **Only** works in `.claude/agents/*.md` definition files, not in `swarm-roles.yaml`. **Dropped from scope.** |
| Model inheritance/parameter on Agent tool | Confirmed for Agent tool (formerly Task). Both tiers of the_swarm's model strategy work as designed.         |
| Task tool renamed to Agent (v2.1.63)      | TaskCreate/Get/List/Update/Stop unchanged. Only the spawn tool renamed.                                      |

## Items

### Step 1: settings.json (foundation)

Create `src/.claude-plugin/settings.json` with user-overridable defaults:

```json
{
  "monitor_cron_interval_seconds": 60,
  "idle_escalation_threshold": 3,
  "reviewer_model": "sonnet",
  "max_agents": 7
}
```

Hook scripts access settings via a shared helper that reads
`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/settings.json` with jq, falling back to
hardcoded defaults.

New file `src/hooks/scripts/lib/read-setting.sh` (sourced helper):

```bash
read_setting() {
  local key="$1" default="$2"
  local settings="${CLAUDE_PLUGIN_ROOT}/.claude-plugin/settings.json"
  if [[ -f "$settings" ]] && command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$key" --arg d "$default" '.[$k] // $d' "$settings" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}
```

**Files:** `src/.claude-plugin/settings.json` (new),
`src/hooks/scripts/lib/read-setting.sh` (new)

### Step 2: agent_id / agent_type in hook scripts

Read new fields from stdin JSON in both hook scripts. Use `agent_id` for more
reliable transcript path resolution; use `agent_type` alongside `teammate_name`
for monitor exemption.

In `teammate-idle.sh`:

1. Extract `AGENT_ID` and `AGENT_TYPE` from stdin JSON (alongside existing
   fields)
2. Replace session_id-based transcript path construction with agent_id-based,
   keeping session_id as fallback:

   ```bash
   if [[ -n "$AGENT_ID" ]]; then
     CANDIDATE="${PARENT_DIR}/subagents/agent-${AGENT_ID}.jsonl"
   elif [[ -n "$SESSION_ID" ]]; then
     CANDIDATE="${PARENT_DIR}/subagents/agent-${SESSION_ID}.jsonl"
   fi
   ```

3. Update monitor exemption to dual-check:
   `[[ "$AGENT_TYPE" == "monitor" || "$TEAMMATE_NAME" == "monitor" ]]`

In `task-completed.sh`: Same field extraction and monitor exemption update. No
transcript path logic exists here -- only the exemption changes.

**Files:** `src/hooks/scripts/teammate-idle.sh`,
`src/hooks/scripts/task-completed.sh`

### Step 3: Hook stop escalation

After N idle/false-completion cycles (default 3, from settings), hard-stop the
teammate instead of nudging infinitely.

Counter storage: per-agent files at
`~/temp/swarm-idle-counters/swarm-idle-{TEAM_NAME}-{TEAMMATE_NAME}.count`.
Per-file approach avoids concurrent-write corruption vs a shared JSON file.

Shared function `nudge_or_stop` (added to each hook script after sourcing
`read-setting.sh`):

```bash
IDLE_THRESHOLD=$(read_setting "idle_escalation_threshold" "3")
COUNTER_DIR="${HOME}/temp/swarm-idle-counters"
mkdir -p "$COUNTER_DIR"

nudge_or_stop() {
  local message="$1"
  local counter_file="${COUNTER_DIR}/swarm-idle-${TEAM_NAME}-${TEAMMATE_NAME}.count"
  local count=0
  [[ -f "$counter_file" ]] && count=$(cat "$counter_file")
  count=$((count + 1))
  echo "$count" > "$counter_file"
  if [[ "$count" -ge "$IDLE_THRESHOLD" ]]; then
    rm -f "$counter_file"
    printf '{"continue": false, "stopReason": "%s stopped after %d cycles without expected output"}\n' \
      "$TEAMMATE_NAME" "$count"
    exit 0
  fi
  echo "$message" >&2
  exit 2
}
```

Replace every `echo ... >&2; exit 2` block in both scripts with a call to
`nudge_or_stop "$message"`.

**Files:** `src/hooks/scripts/teammate-idle.sh`,
`src/hooks/scripts/task-completed.sh`

### Step 4: WorktreeCreate / WorktreeRemove hooks

Track swarm-* worktrees on creation; clean up tracking and counter files on
removal.

Update `src/hooks/hooks.json` -- add two new event entries:

```json
"WorktreeCreate": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/worktree-create.sh"}]}],
"WorktreeRemove": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/worktree-remove.sh"}]}]
```

New `src/hooks/scripts/worktree-create.sh`:

1. Read stdin JSON; extract `worktree_path`, `branch` (field names TBD from
   hooks docs)
2. Filter: only track branches matching `swarm-*`
3. Append to `~/temp/swarm-worktrees.json` (create if absent)
4. Exit 0 always (fail open)

New `src/hooks/scripts/worktree-remove.sh`:

1. Read stdin JSON; extract `branch`
2. If branch matches `swarm-*`: remove from `~/temp/swarm-worktrees.json`
3. Clean up counter files:
   `rm -f ~/temp/swarm-idle-counters/swarm-idle-${branch}-*.count`
4. Exit 0 always

Update `src/skills/swarm/SKILL.md` (lines 41-61): Add a note that
`~/temp/swarm-worktrees.json` can be consulted for a pre-filtered list before
running `git worktree list`. The manual check remains as authoritative fallback.

**Files:** `src/hooks/hooks.json`, `src/hooks/scripts/worktree-create.sh` (new),
`src/hooks/scripts/worktree-remove.sh` (new), `src/skills/swarm/SKILL.md`

### Step 5: Cron scheduling for monitor

Replace vague "periodically check TaskList" with an explicit `CronCreate` call
in the monitor's spawn prompt.

Update `src/skills/swarm/SKILL.md` (lines ~178-188, monitor spawn prompt):

1. Identity and initial SendMessage (unchanged)
2. Call `CronCreate` with `intervalSeconds` set to the resolved
   `monitor_cron_interval_seconds` value (default 60)
3. Cron prompt: check TaskList for stuck/failed/idle anomalies, send SendMessage
   alerts

The lead reads the interval from
`$CLAUDE_PLUGIN_ROOT/.claude-plugin/settings.json` (or defaults to 60) and
includes the concrete number in the monitor's spawn prompt.

Update `src/config/swarm-roles.yaml` (monitor role prompt) -- replace
"periodically" with explicit CronCreate instructions:

```yaml
monitor:
  description: "Watch team progress and alert on anomalies"
  subagent_type: Explore
  prompt: |
    You are a watchdog monitor. On activation:
    1. Send "Monitoring started" to the team lead via SendMessage.
    2. Call CronCreate to schedule recurring checks (interval provided
       in spawn context).

    On each cron tick, call TaskList and check for:
    - Tasks stuck in_progress without progress
    - Unbalanced workloads
    - Failed or blocked tasks needing intervention

    Send alerts via SendMessage. Do not intervene -- report only.
```

**Files:** `src/skills/swarm/SKILL.md`, `src/config/swarm-roles.yaml`

### Step 6: Task to Agent rename

The Task spawn tool was renamed to Agent in v2.1.63. Update all spawn references
in pattern SKILL.md files. `TaskCreate`/`TaskGet`/`TaskList`/`TaskUpdate`/
`TaskStop` are unchanged.

Replace `` `Task` `` (when referring to the spawn tool) with `` `Agent` `` in:

- `src/skills/swarm-fan-out/SKILL.md` -- spawn calls + isolation references
- `src/skills/swarm-swarm/SKILL.md` -- same
- `src/skills/swarm-map-reduce/SKILL.md` -- mapper + reducer spawn calls
- `src/skills/swarm-speculative/SKILL.md` -- implementer + judge spawn calls
- `src/skills/swarm-pipeline/SKILL.md` -- per-stage spawn calls

Grep for `` `Task` `` in these files; replace only spawn-tool references, not
task-management tool references.

**Files:** All 5 pattern `SKILL.md` files

## Sequencing and Commits

```text
Step 1  settings.json + read-setting.sh    foundation; no deps
Step 2  agent_id/agent_type in hooks       modifies hook scripts
Step 3  Hook stop escalation               same scripts as Step 2; do after
Step 4  WorktreeCreate/Remove hooks        new scripts + hooks.json; cleanup ties to Step 3
Step 5  Cron for monitor                   SKILL.md + roles yaml; reads settings from Step 1
Step 6  Task to Agent rename               mechanical; independent
```

One commit per step. Steps 5 and 6 can parallelize with Step 4.

## Verification

After each step, run the relevant linters:

```bash
# Step 1
jsonlint src/.claude-plugin/settings.json

# Steps 2-4 (shell scripts)
shellcheck src/hooks/scripts/teammate-idle.sh
shellcheck src/hooks/scripts/task-completed.sh
shellcheck src/hooks/scripts/worktree-create.sh
shellcheck src/hooks/scripts/worktree-remove.sh
shellcheck src/hooks/scripts/lib/read-setting.sh
jsonlint src/hooks/hooks.json

# Steps 5-6 (markdown + yaml)
markdownlint-cli2 "src/skills/**/*.md"
yamllint src/config/
```

Final pass: grep for stale `Task` spawn references to confirm Step 6
completeness.
