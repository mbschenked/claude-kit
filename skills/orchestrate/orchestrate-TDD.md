# Technical Design Document — `/orchestrate` skill

**Status:** v5 (deployed, not yet run end-to-end) · **Date:** 2026-06-21 · **Owner:** Max Schenk

## 1. Overview

`/orchestrate <task>` is a slash-command skill that runs one coding task through a curated multi-agent build pipeline so the operator triggers a single command instead of hand-orchestrating which subagent to use when. It has two halves:

- **Interactive pre-flight** (runs in the main conversation): explore → grill the operator → propose a plan → audit the plan to pick per-slot specialists → lock.
- **Autonomous build** (a deterministic Workflow): implement → iterative independent review → fix.

It was born from the **superpowers bake-off** (`references/superpowers-bakeoff-2026-06.md`): a dynamic Workflow with an independent review loop scored highest on quality; the curated-kit arm was most efficient; the superpowers methodology-as-instruction arm came last and shipped a bug its own review missed. `/orchestrate` operationalizes the winning insight — **make the review loop structural (a script can't forget it), driven by curated specialists.**

## 2. Goals / Non-goals

**Goals**
- One command; no manual "use X then Y" orchestration.
- The independent review→fix loop is *structural*, not dependent on model recall.
- Resolve design ambiguity with the operator *before* autonomous code is written.
- Route the right kit specialist into each pipeline slot per task.
- A cost/quality dial.

**Non-goals**
- Not a research tool (use `research-scout` / `/deep-research`).
- Not for trivial one-file edits (just do them).
- Not a dynamic decomposer — the pipeline shape is fixed (a "plain workflow," correct for well-defined build tasks).
- Does not Ship (commit/PR) — that happens after it returns.

## 3. Architecture

```
PRE-FLIGHT (interactive, main context)         BUILD (autonomous Workflow, pipeline.js)
1 objective                                    ┌ Implement  [slot agent, from args.agents]
2 Explore subagent → draft findings            │ Review ×N  [axis lenses; evidence required;
3 grill-me (codebase-first)                     │            flag-only-what-breaks-correctness]
4 propose plan                                 │ Fix        [gets implementer context]
5 /audit-plan → slot mapping → operator confirm└ loop review→fix until clean OR maxRounds
6 lock plan + slots                              effort tier sets lens count + maxRounds
7 launch Workflow(task, plan, effort, agents)    empty review round ≠ clean (best-score guard)
8 relay summary
```

The split is **forced by platform constraints**: `grill-me` is interactive, but a Workflow runs autonomously and its agents cannot talk to the operator; and subagents cannot spawn subagents, so multi-agent orchestration must live in the main context or a Workflow (never inside a forked skill). Hence the skill runs in main context (not `context: fork`) and launches the Workflow.

## 4. Components & data flow

| Component | File | Responsibility |
|---|---|---|
| Trigger skill | `SKILL.md` | The 8-step pre-flight procedure (LLM judgment) + the Workflow launch contract. Slash-only. |
| Pipeline | `pipeline.js` | Deterministic build: effort resolution, slot-agent merge, the review→fix loop, schemas. |

**Launch contract** (`SKILL.md` step 7 → `pipeline.js` `args`):
```js
{ task, plan,
  effort: 'quick' | 'balanced' | 'thorough',
  agents: { implement: '<agentType>', fix: '<agentType>',
            reviewLenses: [ { lens, axis, agentType } ] } }   // omit slots left at default
```
`pipeline.js` falls back to `DEFAULTS` for any omitted slot and to `balanced` for absent effort.

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
| `/audit-plan` picks slot specialists, **operator-confirmed** | Per-task routing without brittle keyword regex; suggest-only keeps the operator in control. |
| Effort tiers | Encodes the bake-off cost/quality curve as one knob. |

## 6. Constraints & platform facts

- Subagents cannot spawn subagents (orchestration lives in main context / Workflow).
- Workflow agents are non-interactive (hence all operator interaction is pre-flight).
- Workflow scripts must use a pure-literal `meta`, no `Date.now`/`Math.random`/`new Date`.
- In environments with no build/test harness, the review catches *static* defects only — runtime/activation-order bugs may survive (the bake-off's critical-bug class).

## 7. Testing / verification

- `node --check pipeline.js` (syntax) — passing.
- Validated through 5 rounds of `skill-design-reviewer` (see AgentRef iteration log).
- **Outstanding:** a live end-to-end run is the highest-value unfinished verification. It would confirm (a) the `args` → `pipeline.js` plumbing, (b) the `/audit-plan` → `args.agents` handoff, (c) the review→fix loop convergence, and (d) that repeated `phase('Review')`/`phase('Fix')` calls regroup correctly in `/workflows` (unverified platform behavior).

## 8. Open issues & future work

1. **Purpose-stretch:** `plan-primitive-auditor` audits plan *steps* for primitive fit; using it as a fixed-slot router is the closest-available tool, not a purpose-built one. If valuable, build a dedicated slot-router agent.
2. **Final-round fix is unverified** (no re-review after the last fix) — inherent to a bounded loop.
3. **Never run live** as of v5.
4. **Deferred adoptions** from the kit/GitHub mine: a post-Fix `doc-sync` staleness stage (needs PR #13 pulled into this branch first); optional `session-usage-analyzer` retrospective for long runs.

## 9. Provenance

Designed in the 2026-06-21 session, downstream of the three-arm bake-off (`references/superpowers-bakeoff-2026-06.{md,html,pdf}`). Best-practice patterns sourced from `rules/dynamic-workflow-prompting.md`, `ProjectOptimizer/CHARTER.md`, and the GitHub `tdd-bakeoff.js`.
