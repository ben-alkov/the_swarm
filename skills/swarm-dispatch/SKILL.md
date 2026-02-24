---
name: swarm-dispatch
description: "Dispatch parallel read-only specialists (reviewers, researchers, analyzers) against a target. Use when the user wants concurrent multi-perspective analysis, team review, or parallel research."
---

# Swarm Dispatch

## Overview

Orchestrate parallel specialist agents for concurrent analysis of code,
PRs, or topics. You become the team lead, spawn read-only specialists,
collect their findings, and synthesize a unified report.

**Core principle:** Fan-out N specialists, collect findings, synthesize,
present. No file edits, no implementation — analysis only.

## When to Use

- User asks for review from multiple angles
- User wants parallel independent analysis
- User explicitly asks for "swarm" or "team review"
- Task benefits from diverse concurrent specialist perspectives

## When NOT to Use

- Single-perspective tasks (use a regular agent instead)
- Sequential dependencies between workers
- Simple questions or explorations
- A team already exists in the current session

## Checklist

You MUST complete these steps in order:

1. **Identify goal and target**
2. **Select roles**
3. **Check for existing team**
4. **Confirm with user**
5. **Create team and tasks**
6. **Spawn specialists**
7. **Collect findings**
8. **Synthesize and present report**
9. **Await user instructions**
10. **Shutdown and cleanup** (when user says done)

## Step 1: Identify Goal and Target

Determine from the user's request:

- **Goal**: What is being reviewed/analyzed? (e.g., "security review",
  "PR review", "codebase audit")
- **Target**: Which files, PR, or scope? (e.g., "src/auth/", "PR #42",
  "the entire API layer")

If unclear, ask the user. Do not guess scope.

## Step 2: Select Roles

Roles come from `~/.claude/plugins/swarm/config/swarm-roles.yaml`.

Read the config file to get available roles and presets.

**Selection priority:**

1. User specifies a preset name → use that preset's roles
2. User specifies individual role names → use those
3. User describes what they want → match to appropriate roles
4. Default for "review" requests → use `pr-review` preset

If the user requests roles not in the config, tell them what's available
and ask for clarification. Do not invent roles on the fly.

## Step 3: Check for Existing Team

Only one team can exist per session. Before creating a new team, check
if one already exists.

If a team exists: warn the user and offer to clean it up first
(`TeamDelete`) before proceeding.

## Step 4: Confirm with User

Present the dispatch plan using `AskUserQuestion`:

```text
I'll dispatch a swarm with these specialists:
- security-reviewer: Review for vulnerabilities
- performance-reviewer: Analyze performance issues
- quality-reviewer: Code quality and maintainability

Target: [files/PR/scope]

Proceed?
```

Do NOT spawn anything until the user confirms. No surprise token costs.

## Step 5: Create Team and Tasks

### Team Naming

Use format: `swarm-{goal-slug}-{timestamp}`

Example: `swarm-pr-review-1708200000`

Generate the timestamp from the current date/time as a Unix epoch.

### Create Team

```text
TeamCreate with team_name: "swarm-{goal-slug}-{timestamp}"
```

### Create Tasks

One task per role via `TaskCreate`:

- `subject`: imperative title (e.g., "Review authentication module for
  security vulnerabilities")
- `description`: detailed scope, target files, reporting expectations
- `activeForm`: present-continuous spinner label (e.g., "Reviewing
  authentication security")

All tasks are independent — no `blocks`/`blockedBy` dependencies in v1.

## Step 6: Spawn Specialists

For each role, spawn one teammate via `Task` with:

- `team_name`: the team name from step 5
- `name`: the role name (e.g., `security-reviewer`)
- `subagent_type`: from the role config (typically `Explore`)
- `model`: from the role config (if specified)
- `isolation`: from the role config (if specified)
- `run_in_background`: `true`
- `prompt`: composed from three parts (see below)

### Prompt Construction

Each teammate's prompt is composed from:

#### Part 1: Identity and Instructions

```markdown
Your name is {name}. You are part of team {team_name}.

Instructions:
- Claim your task from TaskList, mark it in_progress, then completed
  when done.
- Send your findings to the team lead via SendMessage when complete.
- Include a summary field in your message (5-10 words).
```

#### Part 2: Role Prompt

The `prompt` field from `swarm-roles.yaml` for this role.

#### Part 3: Goal and Target Context

```markdown
## Goal

{goal description from user}

## Target

{target files, PR, scope, or other context}

{any additional context the user provided}
```

All task-specific context MUST be in the spawn prompt — teammates do not
have access to the lead's conversation history.

## Step 7: Collect Findings

Teammates send findings via `SendMessage`. Messages are delivered
automatically — you do not need to poll.

**Normal flow:** Wait for all specialists to report. Teammates go idle
after sending — this is expected behavior.

**Error handling:**

- Idle teammate without findings: send a message asking for status
- No response after nudge: note in report, mark task as blocked
- TeamCreate failure: report error to user, do not proceed

## Step 8: Synthesize and Present Report

Once all specialists have reported (or you've noted non-reporters):

Synthesize findings into a unified report organized by severity or
theme, not by specialist. Cross-reference overlapping findings.

### Report Structure

```markdown
## Swarm Analysis Report

**Goal:** {goal}
**Target:** {target}
**Specialists:** {list of roles that reported}

### Critical Issues
{findings rated critical/high, with file:line references}

### Important Issues
{findings rated medium/important}

### Suggestions
{lower-priority findings and recommendations}

### Summary
{brief overall assessment — 2-3 sentences}
```

If specialists disagree, note the disagreement rather than silently
picking one perspective.

## Step 9: Await User Instructions

After presenting the report:

- Do NOT fix issues specialists found
- Do NOT shut down the team automatically
- Do NOT proceed past reporting without user input

Wait for the user to decide next steps. They may:

- Ask for more detail on specific findings
- Ask you to fix issues (you would exit delegate mode for this)
- Say they're done (proceed to step 10)

## Step 10: Shutdown and Cleanup

When the user indicates they're done:

1. Send `shutdown_request` to each teammate via `SendMessage`
2. Wait for `shutdown_response` from each
3. Call `TeamDelete` to clean up

## Design Constraints

- **Read-only specialists**: v1 uses `subagent_type: Explore` — no file
  edits, no Bash, no Write. This is enforced at the agent-type level.
- **One team per session**: check before creating.
- **No nested teams**: teammates cannot spawn their own teams.
- **Lead synthesizes**: present a unified report, not raw specialist
  output.
- **User controls lifecycle**: never auto-shutdown.
