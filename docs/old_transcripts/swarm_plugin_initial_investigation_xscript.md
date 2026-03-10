❯ /superpowers:using-superpowers Evaluate
https://gist.githubusercontent.com/kieranklaassen/4f2aba89594a4aea4ad64d753984b2
ea/raw/f9926ad244b48abc93f6d6a7352d61c9a7a4b8d2/SKILL.md (raw text over HTTPS)
for use as a skill. Consider safety in general (do a quick security review), and
 efficacy (does it seem to do what it claims?). Other considerations: in
particular, consider how it might (or might not) integrate and "play well" with
Superpowers.

● I'll fetch the skill content and review it.

● Now let me review this thoroughly.

  Evaluation: orchestrating-swarms Skill

  What It Claims To Do

  A comprehensive reference for multi-agent orchestration using Claude Code's
  TeammateTool and Task system — spawning teams, coordinating workers via
  inboxes, task dependencies, and cleanup.

  ---
  Security Review

  Low risk overall. The skill is purely instructional documentation — it doesn't
   execute commands, inject prompts into other agents, or access external
  services. Specific observations:

  1. No code injection vectors. The skill contains JavaScript/JSON examples but
  they're illustrative, not executable payloads. No eval(), no shell injection
  patterns.
  2. No credential exposure. No API keys, tokens, or secrets. No instructions to
   bypass authentication.
  3. No destructive operations. The file operations are limited to
  reading/writing JSON in ~/.claude/teams/ and ~/.claude/tasks/ — Claude Code's
  own managed directories.
  4. No exfiltration risk. Workers communicate via local inbox files, not
  external endpoints.
  5. Minor concern: worker prompts with $CLAUDE_CODE_AGENT_NAME. Environment
  variable expansion in prompts is standard Claude Code behavior, not a
  vulnerability the skill introduces.
  6. Minor concern: self-organizing swarm pattern. Workers that "race to claim
  tasks" could theoretically conflict, but the task system handles ownership
  atomically. No real risk here.

  Verdict: Safe to use.

  ---
  Efficacy Review

  Mixed — ambitious documentation for a feature set that may not fully exist
  yet.

  Strengths

  - Thorough and well-structured reference covering primitives, lifecycle,
  message formats, and error handling
  - Multiple orchestration patterns (parallel specialists, pipeline, swarm, plan
   approval) with concrete examples
  - Good operational advice (cleanup sequences, backend troubleshooting,
  debugging commands)
  - Clear comparison tables (backends, subagent vs teammate, etc.)

  Concerns

  1. TeammateTool / Teammate() doesn't exist in your current tool set. Your
  available tools include Task, TaskCreate, TaskList, TaskGet, TaskUpdate — but
  no Teammate tool. This skill references Teammate({ operation: "spawnTeam", ...
   }) extensively. It appears to document a feature from a specific plugin
  (compound-engineering) or a future/experimental Claude Code capability that
  isn't present in your environment.
  2. Plugin agent types may not exist. References to
  compound-engineering:review:security-sentinel,
  compound-engineering:research:best-practices-researcher, etc. assume a
  specific plugin is installed. Without that plugin, these subagent_type values
  will fail.
  3. Team/inbox file structure is speculative for your setup. The
  ~/.claude/teams/ and inbox system described here isn't part of standard Claude
   Code — it's either a plugin feature or unreleased functionality.
  4. The await syntax in examples is misleading. Task tool calls don't return
  JavaScript promises; they return tool results. The pseudocode style may
  confuse implementers.

  ---
  Integration with Superpowers

  Partial compatibility, significant friction points:

  Aspect: Task/TaskCreate/TaskList/TaskUpdate
  Compatibility: Compatible
  Notes: Superpowers already uses these; the skill's task dependency patterns
    work
  ────────────────────────────────────────
  Aspect: subagent_type dispatch
  Compatibility: Compatible
  Notes: Standard Task tool parameter; built-in types work
  ────────────────────────────────────────
  Aspect: run_in_background
  Compatibility: Compatible
  Notes: Standard Task tool parameter
  ────────────────────────────────────────
  Aspect: Teammate tool
  Compatibility: Incompatible
  Notes: Not available in your environment
  ────────────────────────────────────────
  Aspect: Plugin agent types
  Compatibility: Unknown
  Notes: Depend on compound-engineering plugin
  ────────────────────────────────────────
  Aspect: dispatching-parallel-agents skill
  Compatibility: Overlapping
  Notes: Superpowers already has a parallel dispatch skill; this skill's swarm
    patterns are more elaborate but use unavailable tools
  ────────────────────────────────────────
  Aspect: subagent-driven-development skill
  Compatibility: Overlapping
  Notes: Similar concept, different implementation
  ────────────────────────────────────────
  Aspect: Brainstorming-first workflow
  Compatibility: Ignored
  Notes: The skill jumps straight to orchestration without brainstorming gates
  ────────────────────────────────────────
  Aspect: Plan mode integration
  Compatibility: Partial
  Notes: The skill's "Plan Approval Workflow" uses Teammate (unavailable), but
    the concept aligns with Superpowers' plan mode

  ---
  Summary

  Dimension: Safety
  Rating: Good
  Notes: No security concerns; purely instructional
  ────────────────────────────────────────
  Dimension: Accuracy
  Rating: Questionable
  Notes: Documents tools/features (Teammate, compound-engineering plugin agents)

    not present in your environment
  ────────────────────────────────────────
  Dimension: Usefulness
  Rating: Partial
  Notes: Task dependency patterns and built-in subagent usage are valid;
    team/inbox/swarm features require unavailable tooling
  ────────────────────────────────────────
  Dimension: Superpowers fit
  Rating: Poor
  Notes: Overlaps with existing skills, ignores Superpowers workflow gates
    (brainstorming), and depends on unavailable primitives

  Recommendation

  Don't install this as-is. The portions that work (Task tool patterns, task
  dependencies, built-in subagent types) are already covered by Superpowers'
  dispatching-parallel-agents and subagent-driven-development skills. The
  portions that are novel (TeammateTool, inbox messaging, swarm
  self-organization) require tooling you don't have.

  If the compound-engineering plugin or a future Claude Code version adds
  TeammateTool, this skill becomes a valuable reference — but it would still
  need modifications to respect Superpowers' workflow gates (brainstorming
  before implementation, verification before completion).

  Alternative: Extract the task dependency patterns (pipeline, fan-out/fan-in)
  as a lightweight addition to your existing dispatching-parallel-agents skill
  rather than importing this entire document.

❯ Please investigate the basis for this statement from a (usually reliable)
   blog:

  "Alongside the release of Claude Opus 4.6, Anthropic has officially
  announced one of the most anticipated features in Claude Code: Swarm mode
   - also known as Claude Code agent teams. What was once a hidden,
  feature-flagged capability is now available to everyone - and it
  fundamentally changes how we think about AI-assisted development." - this
   is supposed to be where the missing tooling comes from (I think?).

● Let me investigate this claim.

● The blog's claim is accurate. Here's what happened:

  Agent Teams / Swarm Mode Is Real

  Anthropic officially shipped "agent teams" alongside Opus 4.6 on February 5,
  2026. The TeammateTool that was missing from my tool set during the skill
  review is a real, first-party Claude Code feature — it was just
  feature-flagged and requires enabling:

  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

  Timeline

  1. ~December 2025: Developers ran strings on the Claude Code binary and
  discovered TeammateTool — a fully implemented but hidden orchestration layer
  with 13 operations.
  2. January 2026: Community tools (claude-sneakpeek, claude-flow, ccswarm)
  reverse-engineered access to the feature before official release.
  3. February 5, 2026: Anthropic officially announced it as "agent teams" with
  the Opus 4.6 launch.

  Why It Wasn't In My Tool Set

  The feature is still gated behind CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1. Your
   environment doesn't have that variable set, so TeammateTool isn't exposed to
  me. That's why my earlier review correctly identified that the tool was
  missing — but incorrectly concluded the skill was documenting vaporware.

  Revised Assessment of the Skill

  Given this context, the orchestrating-swarms skill is documenting real,
  shipping functionality that just needs to be enabled. The compound-engineering
   plugin agent types (security-sentinel, performance-oracle, etc.) appear to be
   from Kieran Klaassen's own plugin, not built-in — but the core TeammateTool
  operations and built-in agent types are legitimate.

  The skill becomes useful if you enable the feature flag. The Superpowers
  integration concerns still stand (no brainstorming gates, overlaps with
  existing dispatch skills), but the "unavailable tooling" objection is
  resolved.

  Assumptions

  - I'm assuming the env var enables TeammateTool in the current Claude Code
  version you're running
  - The compound-engineering:* agent types still require a separate plugin
  installation
  - The skill was likely written by someone who had early access or
  reverse-engineered the binary

  Sources:
  - Anthropic Official Announcement: Introducing Claude Opus 4.6
  - TechCrunch: Anthropic releases Opus 4.6 with new 'agent teams'
  - VentureBeat: Anthropic's Claude Opus 4.6 brings 1M token context and 'agent
  teams'
  - Paddo.dev: Agent Teams — The Switch Got Flipped
  - Paddo.dev: Claude Code's Hidden Multi-Agent System
  - What Is the Claude Code Swarm Feature? (Cyrus)
  - Addy Osmani: Claude Code Swarms
  - The original Gist (Kieran Klaassen)

✻ Sautéed for 1m 6s

❯ OK, I've enabled the flag. Care to take a look at TeammateTool?

● Let me check what's available now.

● The subagent doesn't see a TeammateTool either. Let me check directly — the
  tool list I have access to should reflect the current state.

  Looking at my available tools right now, I have:

  - TeamCreate — Create a new team
  - TeamDelete — Remove team and task directories
  - SendMessage — Send messages to agent teammates (DMs, broadcasts, shutdown
  requests/responses, plan approval)
  - TaskCreate, TaskList, TaskGet, TaskUpdate — Task management
  - Task — Spawn subagents (with optional team_name and name params for
  teammates)

  So the feature is enabled, but Anthropic didn't ship it as a single monolithic
   TeammateTool with 13 operations. Instead, they decomposed it into separate
  tools:

  Skill's Teammate operation: spawnTeam
  Actual tool: TeamCreate
  ────────────────────────────────────────
  Skill's Teammate operation: cleanup
  Actual tool: TeamDelete
  ────────────────────────────────────────
  Skill's Teammate operation: write
  Actual tool: SendMessage (type: "message")
  ────────────────────────────────────────
  Skill's Teammate operation: broadcast
  Actual tool: SendMessage (type: "broadcast")
  ────────────────────────────────────────
  Skill's Teammate operation: requestShutdown
  Actual tool: SendMessage (type: "shutdown_request")
  ────────────────────────────────────────
  Skill's Teammate operation: approveShutdown
  Actual tool: SendMessage (type: "shutdown_response", approve: true)
  ────────────────────────────────────────
  Skill's Teammate operation: rejectShutdown
  Actual tool: SendMessage (type: "shutdown_response", approve: false)
  ────────────────────────────────────────
  Skill's Teammate operation: approvePlan
  Actual tool: SendMessage (type: "plan_approval_response", approve: true)
  ────────────────────────────────────────
  Skill's Teammate operation: rejectPlan
  Actual tool: SendMessage (type: "plan_approval_response", approve: false)
  ────────────────────────────────────────
  Skill's Teammate operation: Spawning teammates
  Actual tool: Task with team_name + name params

  The skill's documentation is structurally correct but uses an older API
  surface (single Teammate tool) that was apparently refactored into multiple
  tools before GA. The concepts, patterns, and workflows all map cleanly — just
  with different tool names.

  Revised verdict

  The skill is a solid conceptual reference for orchestration patterns, but the
  tool invocations need translation to the actual API. Someone using it verbatim
   would hit errors; someone using it as a guide to understand what's possible
  would benefit significantly.

❯ What's your opinion on (let's call it The Swarm) The Swarm vs.
  Superpowers (compare and contrast)?

● Good question. Let me think through this carefully rather than invoke a skill
  — this is a comparative analysis discussion, not an implementation task.

  The Swarm vs. Superpowers: Compare & Contrast

  What They Are

  Superpowers is a process discipline framework. It answers: "How should I
  approach work?" — brainstorm before building, plan before coding, verify
  before claiming done, debug systematically before guessing.

  The Swarm is a parallelism and coordination framework. It answers: "How do I
  split work across multiple agents?" — spawn teammates, manage task
  dependencies, collect results, synthesize.

  They operate on orthogonal axes. Superpowers is about quality of individual
  agent work. The Swarm is about multiplying agents.

  Where They Complement Each Other

  Scenario: Complex feature implementation
  Superpowers alone: Good process, serial execution
  Swarm alone: Parallel but undisciplined
  Combined: Each teammate follows Superpowers discipline
  ────────────────────────────────────────
  Scenario: Code review
  Superpowers alone: Thorough but slow (one perspective)
  Swarm alone: Multiple perspectives, fast
  Combined: Multiple disciplined reviewers
  ────────────────────────────────────────
  Scenario: Debugging
  Superpowers alone: Systematic root-cause analysis
  Swarm alone: Brute-force parallel hypothesis testing
  Combined: Systematic hypotheses tested in parallel
  ────────────────────────────────────────
  Scenario: Refactoring
  Superpowers alone: Plan → execute → verify, serial
  Swarm alone: Parallel file edits, coordination risk
  Combined: Planned decomposition, parallel disciplined execution

  The ideal is obvious: swarm workers that each follow Superpowers process.
  Brainstorm the decomposition, then dispatch teammates who individually do TDD,
   verify before completion, etc.

  Where They Conflict

  1. Brainstorming gates vs. speed. Superpowers insists on brainstorming before
  creative work. The Swarm's value proposition is speed through parallelism.
  Requiring each of 5 teammates to brainstorm independently before acting
  defeats the purpose — but skipping it risks undisciplined parallel chaos.
  2. Plan approval bottleneck. Superpowers' plan-mode workflow assumes a single
  agent getting human approval. In a swarm, do all 5 teammates need plan
  approval? Does only the leader? The skill's plan_approval_request mechanism
  routes approval through the leader, not the human — a significant
  philosophical difference.
  3. Verification ownership. Superpowers' verification-before-completion assumes
   the agent that did the work verifies it. In a swarm, the leader synthesizes
  results from teammates who may have already shut down. Who verifies? The
  leader often can't — it didn't do the work.
  4. Context loss. Each teammate gets a fresh context window with only its
  prompt. It doesn't inherit the conversation history, the brainstorming output,
   or the human's preferences. Superpowers is deeply conversational; the Swarm
  is prompt-driven.

  Structural Differences

  ┌───────────────┬────────────────────────────┬───────────────────────────────┐
  │   Dimension   │        Superpowers         │           The Swarm           │
  ├───────────────┼────────────────────────────┼───────────────────────────────┤
  │ Unit of work  │ Single agent, full         │ Multiple agents, isolated     │
  │               │ conversation               │ contexts                      │
  ├───────────────┼────────────────────────────┼───────────────────────────────┤
  │ Human         │ Continuous (brainstorm,    │ Front-loaded (design          │
  │ interaction   │ approve, review)           │ decomposition), then          │
  │               │                            │ autonomous                    │
  ├───────────────┼────────────────────────────┼───────────────────────────────┤
  │ Quality       │ Process gates (brainstorm  │ Leader synthesis + optional   │
  │ mechanism     │ → plan → TDD → verify)     │ reviewer agents               │
  ├───────────────┼────────────────────────────┼───────────────────────────────┤
  │ Failure mode  │ Over-process (slow,        │ Under-process (fast, sloppy,  │
  │               │ ceremonial)                │ coordination bugs)            │
  ├───────────────┼────────────────────────────┼───────────────────────────────┤
  │ Sweet spot    │ Complex single-track work  │ Embarrassingly parallel work  │
  │               │ requiring judgment         │ with clear boundaries         │
  ├───────────────┼────────────────────────────┼───────────────────────────────┤
  │ Cost model    │ Linear (one agent, longer) │ Multiplicative (N agents,     │
  │               │                            │ shorter but N× tokens)        │
  └───────────────┴────────────────────────────┴───────────────────────────────┘

  My Assessment

  The Swarm is a force multiplier, not a replacement for Superpowers. Using it
  without process discipline gives you 5 agents making the same mistakes in
  parallel. Using Superpowers without the Swarm gives you one careful agent
  doing serial work that could be parallelized.

  The gap is integration. Neither framework accounts for the other:

  - Superpowers has no concept of "delegate to teammate" as a workflow step
  - The Swarm has no concept of "brainstorm before dispatching" or "verify the
  synthesis"

  A combined workflow would look like:

  1. Brainstorm (Superpowers) — understand the problem, with the human
  2. Plan (Superpowers) — decompose into parallelizable units
  3. Dispatch (Swarm) — spawn teammates with clear prompts that embed relevant
  process constraints
  4. Monitor (Swarm) — collect results, handle failures
  5. Verify (Superpowers) — leader verifies the synthesized result before
  claiming done

  Superpowers' existing dispatching-parallel-agents skill is a lightweight
  version of step 3, but it uses fire-and-forget Task subagents rather than
  persistent teammates with inboxes. The Swarm's persistent coordination model
  is strictly more capable for complex multi-step work.

  Trade-off to flag

  The Swarm's biggest risk is cost. Each teammate is a full Claude instance
  burning tokens. A 5-agent swarm reviewing code costs 5× what a single reviewer
   costs. The payoff is wall-clock time and perspective diversity — worth it for
   high-stakes work, overkill for routine tasks. Superpowers' serial approach is
   dramatically cheaper per task.

❯ Brainstorm a fully functional Swarm skill[1] (using what you know from
  your research, especially the Kieran Klaassen gist). After we're done
  with that, we'll look into integrating with Superpowers (but don't start
  on that until I ask).

  [1] I'm overloading the term "skill" here - maybe it will require agents,
   commands, hooks, scripting... 🤷‍♂️. Be creative!

● Using the brainstorming skill to approach this properly.

● Let me explore the existing skill/plugin landscape to understand what we're
  building into.

● Let me look at the most relevant existing skills — dispatching-parallel-agents
   and subagent-driven-development — to understand what we'd be augmenting or
  replacing.

● Now let me see the subagent-driven-development skill and the code-reviewer
  agent for comparison.

● Now let me read the code-reviewer agent definition.

● Good context. Now let me also check the hooks structure to understand what
  hook-based extensions look like.

● Context explored. Here's what I found:

  - Your skill/agent surface: Skills live in ~/.agents/skills/ (your custom) and
   ~/.claude/plugins/cache/.../superpowers/4.3.0/skills/ (Superpowers). Agents
  in the same plugin tree. Hooks via hooks.json.
  - Existing parallel work skills: dispatching-parallel-agents is
  fire-and-forget Task subagents — no teams, no inboxes, no persistence.
  subagent-driven-development is sequential (one implementer at a time) with
  two-stage review.
  - Neither uses TeamCreate/SendMessage/TeamDelete. The entire agent teams API
  is untouched by existing skills.

  Now, first clarifying question:

● User answered Claude's questions:
  ⎿  · Where should the Swarm skill live — as a user-level skill in
     ~/.agents/skills/, as a project-local .claude/agents/ skill, or do you
      want to explore making it a standalone plugin with its own
     agents/hooks/commands? → Standalone plugin

● Standalone plugin. Good choice — gives us the full surface area (skills,
  agents, hooks, commands).

  Next question:

● User answered Claude's questions:
  ⎿  · What orchestration patterns do you want in v1? The Klaassen gist
     describes several. Which matter most to you right now? → Parallel
     specialists

● Focused scope — parallel specialists only for v1. That's the pattern with the
  highest immediate value and clearest semantics.

● User answered Claude's questions:
  ⎿  · How much automation do you want around team lifecycle? The Klaassen
     gist shows manual shutdown sequences (requestShutdown per teammate,
     wait for approval, cleanup). Should the skill automate this, or keep
     the leader in control? → Leader-controlled

● User answered Claude's questions:
  ⎿  · Should teammates be able to use your custom skills and MCP tools
     (context7, deepwiki, osgrep, episodic-memory, etc.), or should they be
      sandboxed to just the built-in Claude Code tools? → Full access
     (Recommended)

● User answered Claude's questions:
  ⎿  · What built-in specialist roles should the plugin ship with? These
     would be pre-defined agent .md files with focused prompts (like
     Superpowers' code-reviewer.md but for swarm use). → Configurable via
     YAML/JSON

● Good. Here's what I've gathered:

  - Standalone plugin with skills/agents/hooks/commands
  - Parallel specialists pattern only for v1
  - Leader-controlled lifecycle (skill teaches the pattern, leader drives)
  - Full tool access for teammates
  - Configurable roles via YAML/JSON with shipped examples

  ---
  Three Approaches

  Approach A: Skill-Only (Documented Pattern)

  A single skill markdown file that teaches the leader how to use TeamCreate,
  Task (with team_name/name), SendMessage, TaskCreate/TaskUpdate, and TeamDelete
   in the parallel specialists pattern. Ships example role configs as reference
  docs.

  Pros: Minimal surface area, easy to maintain, nothing to break
  Cons: Leader must remember all the steps every time, no automation, easy to
  forget cleanup

  Approach B: Skill + Agent + Config (Recommended)

  A skill that defines the orchestration workflow. A leader agent (.md file)
  that can be spawned to be the orchestrator — you tell it "review this PR with
  security, performance, and quality specialists" and it drives the whole flow.
  A roles config (swarm-roles.yaml) where users define reusable specialist
  profiles. Example roles ship with the plugin.

  Pros: Reusable roles, the leader agent encapsulates the coordination logic,
  skill documents when to use it
  Cons: More files to maintain, agent prompt quality is critical

  Approach C: Skill + Agent + Config + Command + Hook

  Everything from B, plus: a command (/swarm) that provides a quick-launch UX
  (e.g., /swarm review --roles security,performance,quality). A hook on
  TeamDelete that captures swarm results to episodic memory before cleanup.

  Pros: Best UX, memory persistence across sessions, quick invocation
  Cons: Most complex, command parsing is fragile in skill-land, hook adds a
  dependency on episodic-memory MCP

  ---
  My recommendation: Approach B. It hits the sweet spot — the roles config gives
   flexibility, the leader agent encapsulates the hard coordination logic, and
  the skill documents when/how to invoke it. Commands and hooks can be added
  incrementally in v2 once the core pattern is proven.

  The key insight: the leader agent is what makes this work. Without it, every
  time you want a parallel specialist review, you'd have to manually remember:
  create team, create tasks, spawn N teammates with the right prompts, monitor
  inboxes, collect results, request shutdowns, wait for approvals, synthesize,
  cleanup. The leader agent does that choreography for you — you just give it a
  goal and a roles config.

● User answered Claude's questions:
  ⎿  · Which approach do you want to go with? → B: Skill + Agent + Config
     (Recommended)

● Approach B it is. Let me present the design in sections.

  ---
  Design Section 1: Plugin Structure

  ~/.claude/plugins/swarm/
  ├── .claude-plugin/
  │   └── plugin.json          # Plugin manifest
  ├── skills/
  │   └── swarm-dispatch/
  │       └── SKILL.md         # "When and how to dispatch a swarm"
  ├── agents/
  │   └── swarm-leader.md      # The orchestrator agent definition
  ├── config/
  │   ├── swarm-roles.yaml     # User-editable role definitions
  │   └── examples/
  │       ├── pr-review.yaml   # Example: security + perf + quality
  │       ├── research.yaml    # Example: multi-source research
  │       └── codebase-audit.yaml  # Example: file-by-file audit
  └── README.md                # Setup and usage docs

  The plugin.json registers the skill and agent with Claude Code. The skill is
  user-invocable (/swarm-dispatch). The agent (swarm-leader) is spawnable via
  Task with subagent_type.

  Does this structure look right so far?

❯ LGTM

● Design Section 2: The Roles Config (swarm-roles.yaml)

  This is where users define reusable specialist profiles. Each role specifies
  what kind of agent to spawn and what instructions it gets.

  # ~/.claude/plugins/swarm/config/swarm-roles.yaml

  # Role definitions for swarm specialists
  # Each role becomes a teammate when dispatched

  roles:
    security-reviewer:
      description: "Review code for security vulnerabilities"
      subagent_type: general-purpose    # or Explore for read-only
      model: sonnet                      # optional, inherits if omitted
      prompt: |
        You are a security specialist. Review the provided code for:
        - Injection vulnerabilities (SQL, command, XSS)
        - Authentication/authorization bypass
        - Sensitive data exposure
        - Insecure deserialization
        - Dependency vulnerabilities

        Report findings with severity (critical/high/medium/low),
        affected file:line, and remediation guidance.

        Send your findings to the team lead when complete.

    performance-reviewer:
      description: "Analyze code for performance issues"
      subagent_type: general-purpose
      model: sonnet
      prompt: |
        You are a performance specialist. Analyze the provided code for:
        - N+1 queries and missing indexes
        - Memory leaks and excessive allocation
        - Inefficient algorithms (O(n²) where O(n) is possible)
        - Missing caching opportunities
        - Blocking I/O in async contexts

        Report findings with impact estimate and specific fix recommendations.

        Send your findings to the team lead when complete.

    quality-reviewer:
      description: "Review code quality and maintainability"
      subagent_type: general-purpose
      model: sonnet
      prompt: |
        You are a code quality specialist. Review the provided code for:
        - SOLID principle violations
        - Dead code and unnecessary complexity
        - Missing or inadequate error handling
        - Test coverage gaps
        - Naming and readability issues

        Categorize issues as: critical (must fix), important (should fix),
        suggestion (nice to have).

        Send your findings to the team lead when complete.

  # Presets: named groups of roles for common workflows
  presets:
    pr-review:
      description: "Standard PR review with three specialists"
      roles: [security-reviewer, performance-reviewer, quality-reviewer]

    security-audit:
      description: "Deep security review only"
      roles: [security-reviewer]

  Key design decisions:

  - subagent_type maps directly to the Task tool parameter — users can use any
  built-in or plugin agent type
  - model is optional; defaults to inheriting from parent (usually Opus)
  - prompt is a template — the leader agent prepends context (files to review,
  PR description, etc.) before dispatching
  - presets are named role groups for quick invocation ("use the pr-review
  preset")
  - Roles are additive — users define new ones without touching the shipped
  examples

  Does this config format work for you?

❯ LGTM

● Design Section 3: The Leader Agent (swarm-leader.md)

  This is the core — an agent definition that encapsulates the full
  parallel-specialists orchestration choreography.

  ---
  name: swarm-leader
  description: |
    Orchestrates parallel specialist teams. Spawned by the user or
    the swarm-dispatch skill to coordinate multiple teammates working
    on the same goal from different angles. Manages the full lifecycle:
    team creation, task setup, teammate dispatch, result collection,
    synthesis, and cleanup.
  model: inherit
  ---

  You are a Swarm Leader — an orchestrator agent that coordinates
  parallel specialist teammates.

  ## Your Lifecycle

  1. **Receive goal and roles** from whoever spawned you
  2. **Create team** via TeamCreate
  3. **Read roles config** from ~/.claude/plugins/swarm/config/swarm-roles.yaml
  4. **Create one task per role** via TaskCreate (all independent, no
  dependencies)
  5. **Spawn one teammate per role** via Task with team_name + name,
     run_in_background: true
  6. **Wait for results** — teammates send findings via SendMessage
  7. **Report to the user** — present raw findings from each specialist
  8. **Await instructions** — the user decides what to do next
  9. **Shutdown teammates** when instructed — SendMessage shutdown_request
     to each, wait for responses
  10. **Cleanup** via TeamDelete when all teammates have shut down

  ## Teammate Prompt Construction

  When spawning each teammate, construct the prompt by combining:

  1. The role's `prompt` from swarm-roles.yaml
  2. The goal/context provided by whoever spawned you (files to review,
     PR description, specific concerns, etc.)
  3. Standard instructions:
     - "Your name is {name}. You are part of team {team_name}."
     - "When finished, send your findings to the team lead using
       SendMessage with type 'message', recipient '{leader_name}'."
     - "Claim your task from TaskList, mark it in_progress, then
       completed when done."

  ## What You Do NOT Do

  - You do NOT synthesize findings into a single report (the user or
    a future integration step does that)
  - You do NOT fix issues the specialists find
  - You do NOT make judgment calls about which findings matter —
    present them all
  - You do NOT shut down teammates without being told to
  - You do NOT proceed past step 7 without user input

  ## Team Naming

  Generate team names as: swarm-{goal-slug}-{timestamp}
  Example: swarm-pr-review-1708200000

  ## Error Handling

  - If a teammate goes idle without sending findings: message them
    asking for status
  - If a teammate crashes (no response after nudge): note it in your
    report, mark their task as blocked, continue with other results
  - If TeamCreate fails: report the error, do not proceed
  - If no roles match the requested preset: report available presets,
    ask for clarification

  Key design decisions:

  - The leader does NOT synthesize. It collects and presents. This keeps the
  leader's role mechanical and leaves judgment to the human (or a future
  Superpowers integration layer).
  - The leader does NOT auto-shutdown. It waits for the user to say "we're
  done." This matches your "leader-controlled" preference.
  - Teammate prompts are composed, not hardcoded. The role config provides the
  specialist instructions; the leader prepends the actual work context.
  - The leader is itself an agent — spawnable via Task with subagent_type:
  "swarm-leader". The skill tells you when to spawn it; the agent knows how to
  orchestrate.

  Does this agent design work?

❯ +1

● Design Section 4: The Skill (swarm-dispatch/SKILL.md)

  This is the entry point — it tells Claude when to spawn a swarm leader and how
   to set it up. Invoked via /swarm-dispatch or matched contextually.

  ---
  name: swarm-dispatch
  description: |
    Dispatch a parallel specialist swarm for tasks that benefit from
    multiple independent perspectives (code review, security audit,
    research). Use when the user wants N specialists examining the
    same target simultaneously. Spawns a swarm-leader agent that
    handles team lifecycle.
  ---

  # Swarm Dispatch

  ## When to Use

  - User asks for review from multiple angles (security + performance + quality)
  - User wants parallel independent analysis of the same target
  - User explicitly asks for a "swarm" or "team review"
  - Task would benefit from diverse specialist perspectives applied concurrently

  ## When NOT to Use

  - Single-perspective tasks (just one reviewer needed)
  - Sequential dependencies between workers (use pipeline pattern instead)
  - Workers would edit the same files (conflict risk)
  - Simple questions or explorations (overkill)

  ## The Flow

  1. **Identify the goal** — what is being reviewed/analyzed?
  2. **Identify the target** — which files, PR, or scope?
  3. **Select roles** — from preset or individual roles in swarm-roles.yaml
  4. **Confirm with user** — show which specialists will be dispatched
  5. **Spawn swarm-leader** — via Task with the goal, target, and roles

  ## Launching the Leader

  Spawn the swarm-leader agent with a prompt that includes:

  - **Goal:** What the swarm should accomplish
  - **Target:** Specific files, directories, PR number, or diff
  - **Roles:** Which roles or preset to use from swarm-roles.yaml
  - **Any special instructions:** User-provided focus areas or constraints

  Example:

      Task({
        subagent_type: "swarm-leader",
        description: "PR review swarm",
        prompt: "Goal: Review PR #42 for merge readiness.
                 Target: Files changed in PR #42 (run gh pr diff 42).
                 Roles: preset 'pr-review' (security, performance, quality).
                 Special: Pay extra attention to the new auth middleware.",
        run_in_background: true
      })

  ## User Confirmation Template

  Before spawning, confirm:

      I'll dispatch a swarm with these specialists:
      - security-reviewer: Review for vulnerabilities
      - performance-reviewer: Analyze performance issues
      - quality-reviewer: Code quality and maintainability

      Target: [files/PR/scope]

      Proceed?

  ## After the Swarm

  The swarm-leader will present findings from each specialist.
  You (the main session agent) then:

  1. Relay the findings to the user
  2. Ask the user what to do (fix issues, dismiss findings, etc.)
  3. When the user is done, tell the leader to shut down the team

  ## What This Skill Does NOT Do

  - Does not implement fixes (that's a separate task)
  - Does not choose roles for the user (confirms first)
  - Does not manage the team lifecycle (the leader agent does that)

  Key decisions:

  - The skill is a launcher, not an orchestrator. It figures out what to
  dispatch and confirms with the user, then hands off to the leader agent.
  - User confirmation before spawn. No surprise token costs — the user sees
  exactly which specialists will run.
  - Clean separation: skill = when/why, leader agent = how, roles config = who.

  Does this work?

❯ In "When not to use", you mention "Workers would edit the same files
  (conflict risk)" - I think the SOP here is: 1) One feature/task/etc.
  BRANCH 2) Swarm team members are allowed (encouraged!) to create
  "personal" worktrees whose commits will be merged onto the single BRANCH
  (obviously this requires a fair bit of coordination and merge-conflict
  resolution). Do you think this is doable within the scope of what we're
  currently working on?

● Good question. Let me think through this honestly.

  For the parallel specialists pattern we're designing (v1), worktrees aren't
  needed. These specialists are readers — they review, analyze, and report
  findings. They don't edit files. The conflict risk warning in "When NOT to
  use" is about a different pattern (parallel implementers), which is out of
  scope for v1.

  For the broader vision where swarm workers implement in parallel — yes, the
  per-worker-worktree pattern is the right SOP. It's also significantly more
  complex:

  - Leader creates the feature branch
  - Each worker gets git worktree add ~/worktrees/{team}/{worker-name} -b
  {worker-branch} {feature-branch}
  - Workers commit to their personal branches
  - Leader (or a dedicated merge agent) rebases/merges worker branches onto the
  feature branch, resolving conflicts
  - Worktrees get cleaned up on shutdown

  This is doable but it's a different orchestration pattern — "parallel
  implementers" — not parallel specialists. It requires:
  - Worktree lifecycle management (create, cleanup)
  - Merge conflict resolution logic (non-trivial)
  - CWD isolation (each worker must Task with the right working directory)
  - Ordering decisions (which worker's changes land first?)

  My recommendation: Remove the "conflict risk" bullet from v1's "When NOT to
  use" since it's irrelevant to read-only specialists. Add a note like "For
  parallel implementation with file edits, see the parallel-implementers pattern
   (planned for v2)." That acknowledges the pattern exists without trying to
  ship it now.

  The worktree-based parallel implementation pattern would be an excellent v2
  addition — it pairs naturally with the existing
  superpowers:using-git-worktrees skill and would be the real "swarm coding"
  capability. But it doubles the design scope and has genuinely hard
  coordination problems (merge conflicts, commit ordering, partial failure
  recovery).

  Does that framing work, or do you want to pull worktree-based implementation
  into v1 scope?

❯ Ah, forgot we had a v2 in mind! Yes, your framing makes complete sense,
  and I like the idea of adding a note referencing v2.

● Good. I'll update that bullet in the skill design accordingly. The "When NOT
  to use" section becomes:

  ## When NOT to Use

  - Single-perspective tasks (just one reviewer needed)
  - Sequential dependencies between workers (use pipeline pattern instead)
  - Simple questions or explorations (overkill)

  Note: Parallel implementation (multiple workers editing files) requires
  worktree-based isolation — planned for v2 (parallel-implementers pattern).

  That covers all four design sections:

  1. Plugin structure — standalone plugin with skills/, agents/, config/
  2. Roles config — YAML with role definitions and presets
  3. Leader agent — orchestrator that manages team lifecycle
  4. Skill — launcher that identifies goals, confirms with user, spawns leader

  Before I write the design doc, one thing I want to flag: the leader agent's
  relationship to the main session.

  There are two ways this can work:

  Option A: Leader runs in background. You spawn the leader via Task with
  run_in_background: true. The leader creates the team, spawns teammates,
  collects results. You check on it periodically or wait for it to finish. This
  is the Klaassen gist's model.

  Option B: Leader runs inline. The main session agent becomes the leader by
  following the skill's instructions directly — no separate leader agent
  spawned. The skill tells the main agent how to call TeamCreate, spawn
  teammates, etc. This is closer to how dispatching-parallel-agents works today.

  Option A gives better isolation (leader has its own context window, doesn't
  pollute your conversation). Option B gives better visibility (you see
  everything happening in real-time).

  Given your "leader-controlled" preference, I went with Option A in the design
  — the leader is a separate agent you spawn and interact with via its results.
  But I want to confirm that's what you want, since it means the orchestration
  happens "offscreen" and you get a summary back.

● User answered Claude's questions:
  ⎿  · Should the swarm leader be a separate background agent (offscreen
     orchestration, summary back to you) or should the main session agent
     act as the leader directly (inline, visible)? → Background agent
     (Recommended)

● Background leader it is. The main session spawns the leader, the leader
  orchestrates offscreen, and you get findings back.

  Let me write the design doc now.

● Clean. Design doc written and lint-free.

● Design doc is at ~/temp/docs/plans/2026-02-17-swarm-plugin-design.md. The
  brainstorming process says the next step is to invoke writing-plans to create
  an implementation plan. But you mentioned wanting to look at Superpowers
  integration after we're done with the core design — and we haven't committed
  this yet.

  How do you want to proceed? Move to the implementation plan now, or review the
   design doc first?
