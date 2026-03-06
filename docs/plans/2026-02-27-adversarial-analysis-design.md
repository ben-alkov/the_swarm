# Adversarial Analysis Design

**Date:** 2026-02-27
**Goal:** Deep cross-cutting adversarial analysis of the_swarm plugin to surface
functionality gaps, unintended consequences, overlooked subtleties, and
dangerous corner cases.

## Pattern

Fan-out — 6 read-only Explore specialists, each examining all files through a
distinct lens. Lead synthesizes into a single consolidated report.

## Analysts

| # | Name                | Lens                                   |
|---|---------------------|----------------------------------------|
| 1 | `state-machine`     | State Machine Coherence                |
| 2 | `failure-modes`     | Failure & Error Propagation            |
| 3 | `platform-friction` | Platform Constraint Friction           |
| 4 | `spec-drift`        | Specification vs. Implementation Drift |
| 5 | `edge-cases`        | Combinatorial Edge Cases               |
| 6 | `bug-validation`    | Known-Bug Fix Validation               |

### 1. State Machine Coherence

Are the step sequences in each skill internally consistent? Do hook gate
conditions align with what agents actually produce? Are there dead states or
impossible transitions?

### 2. Failure & Error Propagation

What happens on agent crash mid-swarm? Hook script errors? Missing dependencies
(`jq`)? Malformed config YAML? Partial team creation? Does the system fail open
or closed, and is that the right choice?

### 3. Platform Constraint Friction

Where do Claude Code platform limits create silent failures? Delegate mode
file-read prohibition vs. lead needing to read config. Context window limits for
spawn prompts. Single-team-per-session constraint. Hook event ordering
assumptions.

### 4. Specification vs. Implementation Drift

Compare `2026-02-25-swarm-v2-design.md` and `2026-02-25-swarm-v2-plan.md`
against every skill, hook, and config file. Where do promises diverge from
reality?

### 5. Combinatorial Edge Cases

Degenerate but valid configurations: 0 roles, 1-agent swarm, 1-stage pipeline,
1-chunk map-reduce, 1-approach speculative, watchdog on unsupported patterns,
conflicting role overrides, preset referencing nonexistent roles.

### 6. Known-Bug Fix Validation

Verify staged (uncommitted) changes fully resolve the 5 known issues: team
naming, watchdog ambiguity, plan approval mismatch, task-graph asymmetry,
undocumented `worker_role`. Check for regressions.

## Execution

- Team name: `swarm-fan-out-adversarial-analysis-{timestamp}`
- Each analyst gets a detailed prompt with their lens, the full file list, and
  instructions to report findings as structured messages (severity, location,
  description, impact, suggested fix)
- Lead collects all findings, deduplicates, cross-references related issues, and
  produces a single prioritized report
- Severity scale: Critical / Important / Suggestion

## Output

Consolidated report delivered in-conversation, organized by severity, with
cross-references where multiple analysts found related facets of the same
underlying issue.
