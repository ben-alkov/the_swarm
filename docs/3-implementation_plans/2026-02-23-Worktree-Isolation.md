---
Worktree Isolation Implementation

Type: Implementation Plan
Date: 2026-02-23
---

<!-- markdownlint-disable first-line-h1 line-length -->

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to
> implement this plan task-by-task.

**Goal:** Add `isolation: worktree` support to the swarm plugin so roles can
opt into isolated git worktrees for writable work.

**Architecture:** Optional `isolation` field in `swarm-roles.yaml` roles. When
set to `worktree`, the dispatch logic in `SKILL.md` auto-upgrades
`subagent_type` to `general-purpose` and passes `isolation: "worktree"` to the
Task tool. One example writable role (`implementer`) and preset demonstrate
usage.

**Tech Stack:** YAML config, Markdown skill definitions, Claude Code Task tool

**Design doc:** `2026-02-23-Worktree-Isolation.md`

---

### Task 1: Add implementer role and preset to swarm-roles.yaml

**Files:**

- Modify: `plugins/swarm/config/swarm-roles.yaml:68-91`

**Step 1: Add the implementer role**

After the `researcher` role block (line 80), add:

```yaml
  implementer:
    description: "Implement code changes in an isolated worktree"
    subagent_type: general-purpose
    isolation: worktree
    prompt: |
      You are an implementation specialist working in an isolated worktree.
      You have full read/write access to the repository.

      For your assigned task:
      - Read and understand the relevant code
      - Make the requested changes
      - Verify your changes work (run tests if applicable)
      - Commit your changes with a clear commit message

      Report what you changed and any issues encountered.

      Send your findings to the team lead when complete.
```

**Step 2: Add the implement-and-review preset**

After the `security-audit` preset (line 91), add:

```yaml
  implement-and-review:
    description: "Implementation with concurrent review"
    roles: [implementer, quality-reviewer]
```

**Step 3: Verify YAML is valid**

Run: `python3 -c "import yaml; yaml.safe_load(open('plugins/swarm/config/swarm-roles.yaml'))"`
Expected: no output (valid YAML)

**Step 4: Commit**

```bash
git add plugins/swarm/config/swarm-roles.yaml
git commit -m "feat(swarm): add implementer role with worktree isolation"
```

---

### Task 2: Update dispatch logic in SKILL.md

**Files:**

- Modify: `plugins/swarm/skills/swarm-dispatch/SKILL.md:29,127-137`

**Step 1: Update "When NOT to Use" section**

Replace line 29:

```markdown
- Tasks requiring file edits (v2 — not yet supported)
```

with:

```markdown
- Tasks requiring file edits without `isolation: worktree` configured on the role
```

**Step 2: Update Step 6 spawn logic**

Replace the Step 6 section (lines 127-137) to add isolation handling. The
updated section should read:

````markdown
## Step 6: Spawn Specialists

For each role, spawn one teammate via `Task` with:

- `team_name`: the team name from step 5
- `name`: the role name (e.g., `security-reviewer`)
- `subagent_type`: from the role config (typically `Explore`)
- `model`: from the role config (if specified)
- `isolation`: from the role config (if specified)
- `run_in_background`: `true`
- `prompt`: composed from three parts (see below)

### Isolation Handling

Before spawning, check each role's `isolation` field:

- If `isolation: worktree` is set:
  - Override `subagent_type` to `general-purpose` (even if the role says
    `Explore` or omits the field)
  - Print a note: `Role {name}: using general-purpose (worktree isolation
    requires write access)`
  - Pass `isolation: "worktree"` to the `Task` tool call
- If `isolation` is absent: use the role's `subagent_type` as-is (default:
  `Explore`), do not pass `isolation` to Task
````

**Step 3: Commit**

```bash
git add plugins/swarm/skills/swarm-dispatch/SKILL.md
git commit -m "feat(swarm): add isolation handling to dispatch logic"
```

---

### Task 3: Update README.md

**Files:**

- Modify: `plugins/swarm/README.md:2-5,39-53,89-121`

**Step 1: Update the opening description**

Replace lines 2-5:

```markdown
Parallel specialist orchestration for Claude Code. Fan out read-only
specialists (reviewers, researchers, analyzers) against a target, collect
findings, and synthesize a unified report.
```

with:

```markdown
Parallel specialist orchestration for Claude Code. Fan out specialists
(reviewers, researchers, analyzers, implementers) against a target, collect
findings, and synthesize a unified report. Supports isolated worktrees for
roles that need write access.
```

**Step 2: Add implementer to the roles table**

After the `researcher` row in the roles table (line 45), add:

```markdown
| `implementer` | Isolated writable agent for code changes |
```

**Step 3: Add implement-and-review to the presets table**

After the `security-audit` row in the presets table (line 53), add:

```markdown
| `implement-and-review` | implementer, quality |
```

**Step 4: Update the Constraints section**

Replace lines 91-92:

```markdown
- **Read-only specialists** — v1 uses `subagent_type: Explore` (no file
  edits, no Bash, no Write)
```

with:

```markdown
- **Read-only by default** — most roles use `subagent_type: Explore` (no file
  edits, no Bash, no Write). Roles with `isolation: worktree` auto-upgrade to
  `general-purpose` and get their own repo copy.
```

**Step 5: Update the Customization section**

Replace the role schema example (lines 101-111) with an expanded version that
documents the `isolation` field:

```yaml
my-custom-role:
  description: "What this role does"
  subagent_type: Explore        # read-only agent type (default)
  model: sonnet                 # optional, inherits from parent
  prompt: |
    Your specialist instructions here.
    Send your findings to the team lead when complete.
```

Then add a second example after it showing a writable role:

```markdown
For roles that need to edit files, add `isolation: worktree`. This gives the
specialist its own copy of the repository and auto-upgrades `subagent_type` to
`general-purpose`:
```

```yaml
my-writable-role:
  description: "Role that edits files in isolation"
  isolation: worktree           # gets own repo copy, auto-upgrades to general-purpose
  model: sonnet
  prompt: |
    Your specialist instructions here.
    Commit your changes before reporting to the team lead.
```

**Step 6: Add an Isolation section before Customization**

Insert a new section between Constraints and Customization:

```markdown
## Isolation

Roles can opt into worktree isolation by setting `isolation: worktree` in their
config. This gives each specialist its own git worktree — an independent copy
of the repository where it can read, write, and commit without affecting other
specialists or the main working directory.

### Behavior

- `isolation: worktree` auto-upgrades `subagent_type` to `general-purpose`
  (Explore agents cannot write files)
- Claude Code creates and manages worktrees automatically
- Worktrees are cleaned up if no changes were made
- If the specialist commits changes, the worktree path and branch are returned
  to the team lead

### When to Use

- Roles that need to edit files (implementers, fixers, refactorers)
- Parallel implementation tasks where specialists must not conflict
- Any role that needs Bash access (running tests, builds, etc.)

### When NOT to Use

- Read-only analysis (reviews, audits, research) — Explore is lighter and
  sufficient
- Roles that need to coordinate on the same files — worktrees isolate, they
  do not share state
```

**Step 7: Commit**

```bash
git add plugins/swarm/README.md
git commit -m "docs(swarm): document worktree isolation support"
```

---

### Task 4: Final verification

**Step 1: Verify YAML validity**

Run: `python3 -c "import yaml; yaml.safe_load(open('plugins/swarm/config/swarm-roles.yaml'))"`
Expected: no output

**Step 2: Verify no broken markdown links**

Run: `markdownlint-cli2 plugins/swarm/README.md plugins/swarm/skills/swarm-dispatch/SKILL.md`
Expected: no errors (or only pre-existing ones)

**Step 3: Review the full diff**

Run: `git log --oneline -3`
Expected: three commits from tasks 1-3
