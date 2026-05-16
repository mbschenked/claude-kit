# VoltAgent workflow mismatch — skip rationale & revisit triggers

> Companion to the 2026-05-15 investigation of `VoltAgent/awesome-claude-code-subagents`.
> Source PDF: `~/ClaudeCode/references/voltagent-subagent-report.{html,pdf}` (not in this repo — generated artifact).

## The core mismatch

VoltAgent subagents are written for a **multi-agent orchestration ecosystem**, not standalone
single-session use. Each agent expects:

- a **`context-manager`** agent — a shared-state/metadata hub (`categories/09-meta-orchestration/`)
- **orchestrators** — `agent-organizer`, `multi-agent-coordinator`, `workflow-orchestrator`
- a **mandatory JSON handshake**: every agent opens by sending a `get_*_context` request to the
  context-manager before doing work
- **cross-agent collaboration** ("integration with other agents") instructions

Max's actual workflow is single Claude Code sessions with task-scoped subagents that return a
result and disappear. There is no persistent fleet and no context-manager, so all of that
scaffolding is **dead code** when an agent is installed standalone — at best inert, at worst it
stalls the agent waiting on a handshake that never resolves. This is why every adopted agent had
to be **hardened** (handshake stripped, cross-agent text removed) per the vendor-vs-harden rule.

## Many skips were workflow mismatch, NOT low quality

Several agents in the investigation were skipped because they assume a scale/structure Max
doesn't operate at — they may be perfectly good agents for the workflow they were built for.

| Skipped agent | Why (workflow, not quality) | Revisit when… |
|---|---|---|
| `git-workflow-manager` | Built for team branching strategy, protected branches, release trains | Max collaborates with a team or runs protected-branch repos |
| `error-detective` | Built for multi-service error correlation / distributed tracing | Max runs a real multi-service backend (overlaps existing `debugger` until then) |
| `seo-specialist` | Assumes an ongoing SEO operation (quarterly roadmaps, competitor benchmarking) | Max runs a sustained content/SEO effort, not a one-page portfolio |
| `content-marketer` | Multi-channel campaign / content-ROI framing | Max does ongoing audience-facing content marketing |
| `ux-researcher` | Formal user-research methodology (interviews, usability studies) | Max runs actual user studies (not solo-dev work) |
| `09-meta-orchestration/*` (`context-manager`, `multi-agent-coordinator`, `agent-organizer`, `workflow-orchestrator`, …) | The orchestration fleet itself | Max builds a genuine multi-agent system — **but** note cross-session state for Max is already solved by supabrain + memory files + the `save` skill, so `context-manager` stays a no-op even then |

Unconditional skips (not workflow — genuinely wrong fit or redundant): `csharp-developer`
(ASP.NET-only, zero game content), `frontend-developer` (assumes React/Vue/Angular; portfolio is
static), `design-bridge` (hard external `awesome-design-md` dependency), `ui-ux-tester`
(requires `chrome-mcp`/`computer-use`; Max has `chrome-devtools`), VoltAgent `code-reviewer` /
`debugger` (name-collide with Max's existing, better versions).

## Evaluation tell

VoltAgent agents embed **fabricated performance numbers** as flavor text — e.g. the
context-manager spec claims it manages *"2.3M contexts with 47ms average retrieval time, 89%
cache hit rate."* These are not benchmarks; they're prose. Treat any hyper-specific metric inside
these files as confabulation, and strip mock-metric language during hardening.

## Adopted in this round (hardened)

`ai-writing-auditor`, `game-developer`, `cpp-pro`, `refactoring-specialist`, `prompt-engineer`,
`ui-designer`, `technical-writer`. Deferred (body never verbatim-confirmed): `accessibility-tester`
— pull the real upstream body and harden only when a portfolio accessibility pass is scheduled.

All adopted files carry a `# Provenance` section recording the upstream path, commit `6f804f0`,
and the specific hardenings applied. Refresh by manual diff, never `cp -R`.
