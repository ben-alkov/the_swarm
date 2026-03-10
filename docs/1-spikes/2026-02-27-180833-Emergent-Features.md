---
Further feature ideas, emergent during adversarial analysis and fixes

Type: Spike
Date: 2026-02-27
Goal: Evaluate usefullness, feasability of a couple of "discovered" potential features
---

<!-- markdownlint-disable ol-prefix first-line-h1 line-length -->

❯ Think hard about the following

- Would it be possible, or even useful, to support multiple instances of the
  same role with different prompts?
- Further investigate areas where pre-flight validation would be a useful
  "safety valve"

● Good questions. Let me investigate both areas systematically.

● Excellent analysis from both agents

## Here's the synthesis

1. Multiple Instances of the Same Role

Today it works in some patterns, breaks in others:

┌─────────────┬──────────────┬────────────────────────────────────────────┐
│   Pattern   │  Same role   │                    Why                     │
│             │     x2?      │                                            │
├─────────────┼──────────────┼────────────────────────────────────────────┤
│ swarm       │ Safe         │ Names are worker-1, worker-2 — role name   │
│             │              │ not embedded                               │
├─────────────┼──────────────┼────────────────────────────────────────────┤
│ map-reduce  │ Safe         │ Names are mapper-1, mapper-2 — index-based │
├─────────────┼──────────────┼────────────────────────────────────────────┤
│ speculative │ Safe         │ Names are approach-1, approach-2 —         │
│             │              │ index-based                                │
├─────────────┼──────────────┼────────────────────────────────────────────┤
│ pipeline    │ Safe across  │ Names are {stage}-{role} — stage prefix    │
│             │ stages       │ disambiguates                              │
├─────────────┼──────────────┼────────────────────────────────────────────┤
│ fan-out     │ Broken       │ Name = role name verbatim — two            │
│             │              │ security-reviewer agents collide           │
└─────────────┴──────────────┴────────────────────────────────────────────┘

The real use case: a user wants two security reviewers focused on different
targets (auth module vs dependencies). The correct answer today is inline role
definitions — give each instance a distinct name (auth-security-reviewer,
deps-security-reviewer) with shared or customized prompts. This already works.

What's missing: fan-out should support an indexed naming scheme when duplicate
roles are intentional. Something like security-reviewer-1, security-reviewer-2.
But this introduces a hook problem — the hooks match on literal names (judge,
monitor), so any indexing scheme must preserve those reserved names.

My recommendation: Don't add multi-instance support to the core role system.
Inline roles already solve the prompt-differentiation case cleanly, and they
sidestep the naming collision entirely. Instead, strengthen fan-out's duplicate
detection to either abort (not just warn) or auto-suffix with -1, -2 when the
user explicitly confirms duplicates.

2. Pre-Flight Validation Gaps

The exploration found 18 gaps across the validation surface.

### Critical (will silently break a run)

┌───────┬──────────────────────────────────────────┬──────────────────────┐
│  Gap  │               Description                │     Fix Location     │
├───────┼──────────────────────────────────────────┼──────────────────────┤
│ GAP-2 │ worker_count: 0 hangs the swarm — no     │ swarm-swarm step 2   │
│       │ lower bound check                        │                      │
├───────┼──────────────────────────────────────────┼──────────────────────┤
│ GAP-4 │ Pipeline stage with roles: [] blocks     │ swarm-pipeline step  │
│       │ relay forever                            │ 2                    │
├───────┼──────────────────────────────────────────┼──────────────────────┤
│ GAP-5 │ Reducer with subagent_type: Explore      │ swarm-map-reduce     │
│       │ can't write output                       │ step 2               │
├───────┼──────────────────────────────────────────┼──────────────────────┤
│ GAP-1 │ isolation: worktree on Explore role —    │ Dispatcher step 3    │
│       │ silently overridden                      │                      │
└───────┴──────────────────────────────────────────┴──────────────────────┘

### Important (confusing or wasted work)

┌────────┬────────────────────────────────────────┬───────────────────────┐
│  Gap   │              Description               │     Fix Location      │
├────────┼────────────────────────────────────────┼───────────────────────┤
│ GAP-8  │ pattern: pipeline with nodes: topology │ Dispatcher step 4     │
│        │  → wrong hooks fire                    │                       │
├────────┼────────────────────────────────────────┼───────────────────────┤
│ GAP-10 │ split_strategy missing → undefined     │ swarm-map-reduce step │
│        │ behavior in split step                 │  2                    │
├────────┼────────────────────────────────────────┼───────────────────────┤
│ GAP-11 │ Typo in subagent_type (e.g., Explorer) │ All pattern skills    │
│        │  → opaque spawn failure                │ step 2                │
├────────┼────────────────────────────────────────┼───────────────────────┤
│ GAP-13 │ watchdog: true but no monitor role →   │ Dispatcher step 4     │
│        │ spawn failure                          │                       │
├────────┼────────────────────────────────────────┼───────────────────────┤
│ GAP-6  │ Inline role missing prompt → agent     │ Fan-out step 2        │
│        │ spawned with no instructions           │                       │
├────────┼────────────────────────────────────────┼───────────────────────┤
│ GAP-14 │ Goal of all special chars → empty slug │ Dispatcher slug       │
│        │  → confusing team name                 │ generation            │
└────────┴────────────────────────────────────────┴───────────────────────┘

### Notable minor

- GAP-15: The shipped security-audit preset always triggers the single-role
  warning. Either add single_role_ok: true or accept the noise.
- GAP-16: Hook transcript grep can false-positive on agents that discuss
  SendMessage in text output.

### Alternative approach: centralized schema validation

Rather than scattering 18 individual checks across 6 skill files, there's a case
for a single validation section in the dispatcher that runs after reading the
config and before routing to any pattern skill. It would validate

- All role references resolve
- Required fields present per role type
- Numeric fields are numeric and in valid ranges
- Topology fields match declared pattern
- Reserved names (monitor, judge) not used as regular role names

The trade-off: centralized validation is DRYer but couples the dispatcher to
pattern-specific knowledge. The current approach (each pattern validates its own
concerns) is more modular but has obvious coverage gaps.

---

Want me to implement any of these? I'd suggest prioritizing the 4 critical gaps
(GAP-1, 2, 4, 5) as a next batch — they're all straightforward validation
additions to existing skill files.

❯ Your alternative approach here dovetails nicely with the earlier alternative
path from the adversarial analysis: "Rather than fixing each pattern skill
individually (watchdog, isolation handling, role validation, relay enforcement),
consider extracting shared behavior into the dispatcher or a shared preamble
referenced by all pattern skills. This trades skill file independence for
consistency guarantees".

I actually missed it when I reviewed the earlier report, bfore implementation,
but it's been on my mind since then.

So, if we're talking about

- a single validation section in the dispatcher
- extracting shared behavior into the dispatcher
- possibly *also* having a shared preamble referenced by all pattern skills

...what are the tradeoffs here? Do you think it's something worth pursuing?

● Good question. Let me think through the architectural tradeoffs carefully
before recommending anything.

## The Three Options

### Option A: Centralized in Dispatcher Only

The dispatcher reads config, validates everything, then routes to the pattern
skill with a "pre-validated" guarantee.

Wins

- Single place to maintain validation logic
- Pattern skills get simpler — they trust inputs are valid
- Easy to audit coverage — one file, one section

Costs

- Dispatcher must know pattern-specific constraints (e.g., "speculative needs
  approach_count >= 2", "map-reduce needs split_strategy"). This couples the
  dispatcher to every pattern's schema.
- Adding a new pattern means editing the dispatcher validation and adding the
  new skill file. Today you only add a skill file.
- The dispatcher is already the longest skill file. More validation makes it
  harder for the LLM to hold in context and follow reliably.

### Option B: Shared Preamble Referenced by Pattern Skills

A separate file (e.g., skills/swarm-shared/VALIDATION.md) that each pattern
skill says "read and follow before proceeding." Contains common checks: role
existence, subagent_type validation, isolation/subagent_type consistency,
reserved name protection.

Wins

- Pattern skills stay independent — they just @include the shared checks
- Pattern-specific validation stays local (approach_count in speculative,
  split_strategy in map-reduce)
- Adding a new pattern doesn't touch the dispatcher or preamble — you include it
  and add your own checks
- Clean separation: shared preamble = schema/config correctness, pattern skill =
  semantic correctness

Costs

- LLM must reliably read and follow a referenced file mid-execution. This is the
  big risk — Claude Code skills don't have a formal @include mechanism. The
  instruction would be "Read
  $CLAUDE_PLUGIN_ROOT/skills/swarm-shared/VALIDATION.md and follow it now."
  That's a soft contract.
- Two-file coordination: if someone edits the preamble without checking all
  consumers, a new check could conflict with a pattern's assumptions.
- Harder to test — the preamble's behavior depends on which pattern invoked it.

### Option C: Dispatcher Does Universal Checks, Pattern Skills Do Pattern-Specific

#### Split validation into two layers

1. Dispatcher validates config-level concerns that are pattern-agnostic: role
   references resolve, subagent_type is valid, numeric fields are numeric,
   reserved names aren't hijacked, watchdog: true implies monitor role exists,
   deprecated implies successor exists.
2. Pattern skills validate their own semantic constraints: approach_count range,
   stage non-empty, split_strategy present,
   single-role/single-stage/single-chunk warnings.

#### Wins

- Natural split along knowledge boundaries — the dispatcher knows config
  structure, pattern skills know their own semantics
- No coupling in either direction — dispatcher doesn't need to know what
  approach_count means, speculative doesn't need to validate role existence
- Adding a new pattern doesn't touch the dispatcher (unless it introduces new
  config-level fields)
- No soft @include contract

#### Costs

- Two validation passes means the user could get config-level errors from the
dispatcher, fix them, then get semantic errors from the pattern skill. Two
rounds of feedback instead of one. (Mitigated: both are pre-confirmation, so
no wasted work.)
- Some checks are borderline — is "reducer role must be general-purpose" a
config concern or a map-reduce semantic concern? You'll make judgment calls at
  the boundary.

## My Recommendation

Option C.

### Here's why

1. The coupling concern is real. The dispatcher currently knows nothing about
   approach_count, split_strategy, or stage topology. Pushing that knowledge
   into it (Option A) means every new pattern bleeds into the dispatcher. That's
   the opposite of the plugin's design — pattern skills are supposed to be
   self-contained instruction sets.
2. The @include mechanism doesn't exist (Option B). We'd be relying on an LLM
   reliably reading a second file mid-skill-execution. It works today in the
   dispatcher's "read and follow the pattern skill" handoff, but that's a
   terminal handoff — control doesn't return. A preamble that says "do these
   checks, then continue with your own steps" is a mid-flow interruption. It'll
   work most of the time, but it's a fragility we don't need.
3. Option C maps to how the system already works. The dispatcher already reads
   config, selects preset, determines pattern, and routes. Adding a "validate
   config shape" step between "read config" and "route to pattern" is natural.
   Pattern skills already have a Validation step. We're just being explicit
   about which checks live where.

### What goes where in Option C

Dispatcher (config-shape validation, after step 3)

- All role references in preset resolve to global or inline definitions
- Every role has prompt and subagent_type
- subagent_type is one of Explore, general-purpose
- isolation: worktree on a role → subagent_type must be general-purpose (or warn
  that it will be overridden)
- Numeric fields (worker_count, approach_count) are positive integers
- deprecated: true → successor should exist
- watchdog: true → monitor role must exist
- Goal slug non-empty after transformation
- Pattern field matches topology keys (pipeline → has stages or nodes, not
  roles)

Pattern skills (semantic validation, existing step 2)

- Fan-out: no duplicates, single-role warning
- Pipeline: non-empty stages, per-stage non-empty roles, cycle detection, valid
  depends_on
- Map-reduce: split_strategy present and recognized, single-chunk bypass
- Speculative: approach_count >= 2
- Swarm: worker_count range warning (>7)

The 4 critical gaps (GAP-1, 2, 4, 5) split cleanly: GAP-1 goes to dispatcher,
GAP-2 lower-bound goes to dispatcher (it's a numeric range check), GAP-4 and
GAP-5 stay in their pattern skills.

---

Worth pursuing? Yes — but as a focused addition, not a rewrite. The dispatcher
gets one new subsection ("Config Validation") between steps 3 and 4, and the
pattern skills keep their existing validation steps with the gaps filled. No
structural changes, no new files, no include mechanism.
