---
Compare/contrast analysis of the official agent-teams documentation and the-swarm's full implementation
Type: Spike
Date: 2026-03-14-112611
Goal: A thorough review to discover gaps or conflicts, and resolve some specific questions
---

<!-- markdownlint-disable first-line-h1 no-bare-urls -->

❯ Use the-swarm. Carefully read https://code.claude.com/docs/en/agent-teams.md
(raw markdown formatted text over HTTPS), and compoare/contrast with
the-swarm's documentation and, more importantly, implementation.

I'm highly concerned about the phrases "multiple Claude Code **instances**" and
"Unlike subagents, which run within a single session and can only report back to
the main agent, you can also interact with individual teammates directly without
going through the lead", specifically;

- Does this mean that a human must launch multiple instances of claude for this
  to work?
- Are we "leaving features on the table" by not leveraging "bypassing the lead
  for direct individual teammate interaction"?
- Other gaps or conflicts as discovered

● Let me fetch the official docs and read the-swarm's implementation in parallel

● Let me find the actual skill file paths.

● Now let me check memory for any prior context on this topic.

● Recalled 1 memory (ctrl+o to expand)

● Here's my analysis after reading both the official agent-teams documentation
and the-swarm's full implementation.

## "Multiple Claude Code instances" — Does the human launch them manually?

No. The lead session spawns teammates programmatically. When the official docs
say "multiple Claude Code instances," they mean the system creates separate
processes/sessions for each teammate. The human interacts with one session (the
lead), tells it to create a team, and the lead handles spawning.

- the-swarm already uses exactly this mechanism — the Agent tool with team_name,
  run_in_background: true, TeamCreate, TaskCreate, SendMessage. These ARE the
  agent-teams API
- the-swarm is a higher-level orchestration layer on top of the same
  infrastructure the official docs describ

The term "instances" is architecturally accurate (each teammate is a separate
Claude Code process with its own context window) but misleading if read as "the
user must manually launch multiple terminals."

<!-- markdownlint-disable-next-line line-length -->
## "Bypassing the lead for direct individual teammate interaction" — Are we leaving features on the table?

Partially, but it's mostly a UX gap rather than an architectural one.

The official docs describe two interaction modalities

- In-process mode: Shift+Down to cycle through teammates, type directly to them
- Split-pane mode: click into a teammate's pane for direct interaction

the-swarm doesn't prevent this — teammates spawned by the-swarm are regular
agent-team members, so Shift+Down should work. But the-swarm doesn't surface or
encourage it either. All skill instructions route communication hub-and-spoke
through the lead

- Teammates → SendMessage to lead
- Lead synthesizes → presents to user
- User → lead → delegates to teammates

What's potentially left on the table

┌───────────────────────────────────┬─────────────────────────────────────────┐
│         Official capability       │             the-swarm usage             │
├───────────────────────────────────┼─────────────────────────────────────────┤
│ User talks directly to a teammate │ Not mentioned in skill docs             │
├───────────────────────────────────┼─────────────────────────────────────────┤
│ Teammate-to-teammate messaging    │ Not used — all comms go through lead    │
├───────────────────────────────────┼─────────────────────────────────────────┤
│ broadcast (send to all teammates) │ Not used                                │
├───────────────────────────────────┼─────────────────────────────────────────┤
│ Teammates                         │ Not designed for — the lead synthesizes │
| "challenge each other's findings" |                                         |
└───────────────────────────────────┴─────────────────────────────────────────┘

The "competing hypotheses" example in the official docs is particularly
interesting: "Spawn 5 agent teammates to investigate different hypotheses. Have
them talk to each other to try to disprove each other's theories." This
peer-debate pattern has no equivalent in the-swarm.

However, there's a real question of whether teammate-to-teammate communication
is reliable enough to build on. The official docs themselves list it as
experimental with known limitations. the-swarm's hub-and-spoke model is more
predictable and debuggable.

Concrete opportunities if we wanted to leverage this

1. Add a note to fan-out/speculative skill outputs telling the user they can
   Shift+Down to interact with individual teammates
2. A new "debate" pattern where specialists are prompted to message each other
   before reporting to the lead
3. Use broadcast for the shutdown sequence instead of iterating SendMessage per
   teammate

## Other Gaps and Conflicts

### Feature flag requirement (documentation gap)

The official docs state agent teams require CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
in settings.json or environment. the-swarm's plugin.json, README, and skill
files don't mention this prerequisite. If TeamCreate/SendMessage/etc. are gated
behind this flag, the-swarm silently fails without it.

### Display mode configuration

The official docs describe teammateMode settings ("in-process", "tmux", "auto").
the-swarm spawns all teammates with run_in_background: true, which maps to
in-process mode.

The-swarm doesn't offer or document the split-pane option, which would let users
see all teammate output simultaneously. This is especially valuable for the
speculative pattern where watching competing implementations side-by-side would
be natural.

### Self-coordination vs. lead-coordination

The official docs emphasize teammates self-coordinating through the shared task
list: "Shared task list with self-coordination." the-swarm's swarm-swarm pattern
does this (workers self-claim from a pool), but the other patterns are heavily
lead-directed. The pipeline relay (step 8) is entirely lead-managed — the lead
collects findings, forwards them, waits for acknowledgment. The official docs
suggest teammates can coordinate among themselves.

### Teammate-initiated discovery

The official docs note: "The team config contains a members array with each
teammate's name, agent ID, and agent type. Teammates can read this file to
discover other team members." the-swarm doesn't tell teammates about this —
they're only told about the lead. This could enable peer messaging if desired.

### Shutdown semantics

the-swarm sends shutdown_request via SendMessage and waits for
shutdown_response. The official docs describe a different mechanism: "The lead
sends a shutdown request. The teammate can approve, exiting gracefully, or
reject with an explanation." These might be the same thing under the hood, but
the-swarm's shutdown protocol may not match the official API if there's a
dedicated shutdown tool/message type.

### No conflict on constraints

Both agree on: one team per session, no nested teams, lead is fixed, permissions
inherit from lead, no session resumption for teammates. No conflicts here.

## Summary

┌─────────────────────────────┬────────────────────────────────────────────────┐
│            Area             │                   Assessment                   │
├─────────────────────────────┼────────────────────────────────────────────────┤
│ Architecture                │ Aligned — the-swarm builds directly on         |
|                             | the agent-teams primitives                     │
├─────────────────────────────┼────────────────────────────────────────────────┤
│ "Multiple instances"        │ Not a human concern — system-managed, not      │
|                             | manual                                         |
├─────────────────────────────┼────────────────────────────────────────────────┤
│ Direct teammate interaction │ Low-priority gap — UX convenience, not         |
|                             | architectural                                  │
├─────────────────────────────┼────────────────────────────────────────────────┤
│ Peer-to-peer messaging      │ Potential feature — enables debate/challenge   |
|                             | patterns                                       │
├─────────────────────────────┼────────────────────────────────────────────────┤
│ Feature flag docs           │ Should document — users need                   |
|                             | CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS           │
├─────────────────────────────┼────────────────────────────────────────────────┤
│ Display mode                │ Could document — split-pane option exists but  |
|                             | isn't surfaced                                 │
├─────────────────────────────┼────────────────────────────────────────────────┤
│ Shutdown protocol           │ Should verify — may need alignment with        |
|                             | official API                                   │
└─────────────────────────────┴────────────────────────────────────────────────┘

### Assumptions

- TeamCreate, SendMessage, TaskCreate etc. are the same tools in both the
  official docs and the-swarm's runtime
- The CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS flag gates these tools (not verified
  — the tools appear in the deferred tools list regardless, but might fail at
  runtime without the flag)
- the-swarm's Agent tool with team_name produces the same "teammate"
  relationship described in the official docs

### Alternative path

Rather than retrofitting peer-to-peer communication into existing patterns, a
more targeted approach: add a single new debate pattern (or modifier) that
specifically enables the "competing hypotheses with inter-agent challenge"
workflow from the official docs. This keeps the existing patterns simple and
hub-and-spoke while offering the peer capability where it genuinely adds value.
