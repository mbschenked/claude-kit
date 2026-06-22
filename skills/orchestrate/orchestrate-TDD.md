# Technical Design Document — `/orchestrate` skill

**Status:** v6 (deployed; first live run 2026-06-22) · **Date:** 2026-06-21 (v6 2026-06-22) · **Owner:** Max Schenk

## 1. Overview

`/orchestrate <task>` is a slash-command skill that runs one coding task through a curated multi-agent build pipeline so the operator triggers a single command instead of hand-orchestrating which subagent to use when. It has two halves:

- **Interactive pre-flight** (runs in the main conversation): explore → grill the operator → propose a plan → audit the plan to pick per-slot specialists **and models** → lock.
- **Autonomous build** (a deterministic Workflow): implement → iterative independent review → fix.

It was born from the **superpowers bake-off** (`references/superpowers-bakeoff-2026-06.md`): a dynamic Workflow with an independent review loop scored highest on quality; the curated-kit arm was most efficient; the superpowers methodology-as-instruction arm came last and shipped a bug its own review missed. `/orchestrate` operationalizes the winning insight — **make the review loop structural (a script can't forget it), driven by curated specialists.**

## 2. Goals / Non-goals

**Goals**
- One command; no manual "use X then Y" orchestration.
- The independent review→fix loop is *structural*, not dependent on model recall.
- Resolve design ambiguity with the operator *before* autonomous code is written.
- Route the right kit specialist **and model** into each pipeline slot per task.
- A cost/quality dial.

**Non-goals**
- Not a research tool (use `research-scout` / `/deep-research`).
- Not for trivial one-file edits (just do them).
- Not a dynamic decomposer — the pipeline shape is fixed (a "plain workflow," correct for well-defined build tasks).
- Does not Ship (commit/PR) — that happens after it returns.

## 3. Architecture

```
PRE-FLIGHT (interactive, main context)         BUILD (autonomous Workflow, pipeline.js)
1 objective                                    ┌ Implement  [slot agent+model, from args.agents]
2 Explore subagent → draft findings            │ Review ×N  [axis lenses, each agent+model;
3 grill-me (codebase-first)                     │            evidence required; flag-only-breaks]
4 propose plan                                 │ Fix        [slot agent+model; implementer ctx]
5 /audit-plan → slot+model mapping → confirm   └ loop review→fix until clean OR maxRounds
6 lock plan + slots+models                       effort tier sets lens count + maxRounds
7 launch Workflow(task, plan, effort, agents)    empty review round ≠ clean (best-score guard)
8 relay summary
```

The split is **forced by platform constraints**: `grill-me` is interactive, but a Workflow runs autonomously and its agents cannot talk to the operator; and subagents cannot spawn subagents, so multi-agent orchestration must live in the main context or a Workflow (never inside a forked skill). Hence the skill runs in main context (not `context: fork`) and launches the Workflow.

## 4. Components & data flow

| Component | File | Responsibility |
|---|---|---|
| Trigger skill | `SKILL.md` | The 8-step pre-flight procedure (LLM judgment) + the Workflow launch contract. Slash-only. |
| Pipeline | `pipeline.js` | Deterministic build: effort resolution, per-slot agent+model merge (`resolveSlot`), `args` parse-guard, the review→fix loop, schemas. |

**Launch contract** (`SKILL.md` step 7 → `pipeline.js` `args`):
```js
{ task, plan,
  effort: 'quick' | 'balanced' | 'thorough',
  agents: { implement: { agentType, model }, fix: { agentType, model },
            reviewLenses: [ { lens, axis, agentType, model } ] } }
// each slot: a bare '<agentType>' string (keeps default model) OR a { agentType, model } object;
// omit any slot/field left at default
```
`pipeline.js` (`resolveSlot`) falls back to `DEFAULTS` (each slot carries `agentType` + `model`) for any omitted slot/field, to `balanced` for absent effort, and `JSON.parse`-guards a stringified `args` so a string payload no longer silently collapses into `task`.

## 5. Key design decisions & rationale

| Decision | Why |
|---|---|
| Skill runs in **main context**, not `context: fork` | A forked subagent can't spawn the pipeline's agents (no nested subagents). |
| `disable-model-invocation: true` (slash-only) | A multi-agent run is expensive + side-effecting; explicit opt-in (also satisfies the Workflow tool's opt-in). |
| `allowed-tools: Task, Skill, Workflow` | Task (Explore + plan-primitive-auditor), Skill (grill-me), Workflow (launch) — minimal set, no per-use prompts. |
| `${CLAUDE_SKILL_DIR}/pipeline.js` path | Survives moving the skill to project scope; never hardcode `~/.claude/...`. |
| **Independent** review (diverse axis lenses, not self-review) | The bake-off's decisive quality lever — self-review missed the critical bug independent review caught. |
| Reviewers flag **only what breaks correctness or a stated requirement** | Kills the "reviewer-finds-gaps → over-engineering" trap. |
| `evidence` required in findings schema | Demand proof (file:line / diff / clause), not bare assertions. |
| **Iterative** review→fix loop, capped at `maxRounds` | Evaluator-optimizer pattern; single-pass leaves the last fix unverified. |
| Empty review round ≠ clean (`reviewFailed`) | tdd-bakeoff best-score lesson: a failed round must not masquerade as a pass. |
| `grill-me` is **codebase-first** | Resolve questions by reading code before asking; bake-off ask-first variants scored 12–20 pts lower on fidelity. |
| `/audit-plan` picks slot specialists **and models**, **operator-confirmed** | Per-task routing without brittle keyword regex; suggest-only keeps the operator in control. |
| **Model tiered per slot**, not one global model | Model gains beat fan-out gains per token: reach for `opus` on `implement` + the single highest-risk lens, keep `sonnet` for ordinary work, drop to `haiku` for mechanical slots. (Added v6 after the live run exposed a hardcoded-Sonnet default.) |
| Effort tiers | Encodes the bake-off cost/quality curve as one knob. |

## 6. Constraints & platform facts

- Subagents cannot spawn subagents (orchestration lives in main context / Workflow).
- Workflow agents are non-interactive (hence all operator interaction is pre-flight).
- Workflow scripts must use a pure-literal `meta`, no `Date.now`/`Math.random`/`new Date`.
- In environments with no build/test harness, the review catches *static* defects only — runtime/activation-order bugs may survive (the bake-off's critical-bug class).

## 7. Testing / verification

- `node --check pipeline.js` (syntax) — passing.
- Validated through 5 rounds of `skill-design-reviewer` (see AgentRef iteration log).
- **First live end-to-end run — 2026-06-22** (TOG `UTOGGA_Counter`, scoped core). Confirmed (a) the `args` → `pipeline.js` plumbing, (b) the `/audit-plan` → `args.agents` handoff, (c) review→fix loop convergence (round 1, 0 findings), and (d) repeated `phase('Review')`/`phase('Fix')` regroup correctly. The run **exposed two bugs** (Sonnet hardcoded with no model override; a stringified `args` silently collapsing to defaults) — both fixed in v6 (PR #16). It also confirmed (c): the static (no-compile) environment limits verification to code review.
- **Bake-off (2026-06-22):** same task given to a matched hand-authored dynamic Workflow (same agents + Opus). An Opus 3-judge panel scored `/orchestrate` ~89 vs ~81 — the win came from scope discipline + documentation, not raw coding (code bodies near-identical). Read: the edge is the disciplined locked-plan handoff, not a coding-capability gap.

## 8. Open issues & future work

1. **Purpose-stretch:** `plan-primitive-auditor` audits plan *steps* for primitive fit; using it as a fixed-slot router (now for agent **and** model) is the closest-available tool, not a purpose-built one. Held up in the live run, but a dedicated slot-router agent is still the clean future fix.
2. **Final-round fix is unverified** (no re-review after the last fix) — inherent to a bounded loop.
3. ~~Never run live~~ — **done 2026-06-22** (§7); the two bugs it found are fixed in v6 (PR #16), the AgentRef in PR #17.
4. **Deferred adoptions** from the kit/GitHub mine: a post-Fix `doc-sync` staleness stage (needs PR #13 pulled into this branch first); optional `session-usage-analyzer` retrospective for long runs.

## 9. Provenance

Designed in the 2026-06-21 session, downstream of the three-arm bake-off (`references/superpowers-bakeoff-2026-06.{md,html,pdf}`). Best-practice patterns sourced from `rules/dynamic-workflow-prompting.md`, `ProjectOptimizer/CHARTER.md`, and the GitHub `tdd-bakeoff.js`.
