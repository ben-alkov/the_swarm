❯ I found this comment online

  "The gist documents Leader, Swarm, Pipeline, Council, and Watchdog
  patterns. The repo adds Task Graph, Fan-Out, Map-Reduce, Speculative, and
   Background patterns."

  How many interaction patterns are you aware of? Which ones have already
  been implemented?

● Let me research this before answering.

● Explore(Research agent team patterns)
  ⎿  Done (36 tool uses · 84.9k tokens · 5m 22s)
  (ctrl+o to expand)

● Web Search("Claude Code agent teams interaction patterns "Leader" "Swarm"
            "Pipeline" "Council" "Watchdog" "Fan-Out" "Map-Reduce" 2025 2026")
  ⎿  Did 1 search in 34s

● There are 10 documented interaction patterns across two sources. Here's the
  full inventory and what's implemented in your environment:

  All 10 Patterns

  From the Kieran Klaassen gist (5 patterns)

  Pattern: Leader
  Description: One lead orchestrates, assigns tasks, synthesizes results
  Implemented?: Yes — swarm plugin + superpowers executing-plans
  ────────────────────────────────────────
  Pattern: Swarm
  Description: Leader spawns scout + workers who self-claim from task pool
  Implemented?: Partially — task self-claiming primitives exist (TaskList →
    TaskUpdate with owner), no dedicated skill
  ────────────────────────────────────────
  Pattern: Pipeline
  Description: Sequential stages with blocks/blockedBy auto-unblocking
  Implemented?: No — primitives exist in TaskUpdate, no pattern skill. Noted as
    v2 in our design.
  ────────────────────────────────────────
  Pattern: Council
  Description: Multiple advocates research independently, then debate
  Implemented?: No
  ────────────────────────────────────────
  Pattern: Watchdog
  Description: Monitor agent observes others, intervenes on failures
  Implemented?: No — TeammateIdle/TaskCompleted hooks are a lightweight version
    of this

  From the claude-sneakpeek repo (5 additional patterns)

  Pattern: Fan-Out
  Description: Parallel read-only specialists, collect + synthesize
  Implemented?: Yes — this is exactly what we just built (swarm-dispatch)
  ────────────────────────────────────────
  Pattern: Task Graph
  Description: DAG of tasks with dependency edges
  Implemented?: No — primitives exist (blocks/blockedBy), no orchestration skill
  ────────────────────────────────────────
  Pattern: Map-Reduce
  Description: Split input → parallel map → reduce/merge results
  Implemented?: No
  ────────────────────────────────────────
  Pattern: Speculative
  Description: Run multiple approaches concurrently, pick the winner
  Implemented?: No
  ────────────────────────────────────────
  Pattern: Background
  Description: Long-running async tasks (run_in_background: true)
  Implemented?: Partially — Task tool supports it, no pattern skill

  Already implemented in your environment

  Implementation: Swarm plugin (swarm-dispatch)
  Patterns covered: Fan-Out, Leader
  ────────────────────────────────────────
  Implementation: superpowers:dispatching-parallel-agents
  Patterns covered: Fan-Out (lightweight, no teams)
  ────────────────────────────────────────
  Implementation: superpowers:subagent-driven-development
  Patterns covered: Pipeline (2-stage review chain)
  ────────────────────────────────────────
  Implementation: superpowers:executing-plans
  Patterns covered: Leader (batch execution + checkpoints)

  Summary

  - 4 of 10 have full or partial implementations
  - 3 of 10 have platform primitives but no orchestration skill (Swarm
  self-claiming, Pipeline/Task Graph via blocks/blockedBy, Background via
  run_in_background)
  - 3 of 10 have no implementation at all (Council, Map-Reduce, Speculative)

  The highest-value next patterns to implement would be Pipeline (you already
  planned it for v2 with worktree isolation) and Council (straightforward
  extension of Fan-Out where specialists debate rather than just report
  independently).

  Sources:
  - Kieran Klaassen's orchestration gist
  - Scott Spence — Unlock Swarm Mode
  - Addy Osmani — Claude Code Swarms
  - alexop.dev — From Tasks to Swarms
