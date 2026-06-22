# AgentRef — `/orchestrate` skill

Compact recall index for the `/orchestrate` skill. For full rationale see `orchestrate-TDD.md`.

## What it is (one line)

A slash-only skill: interactive pre-flight (explore → grill-me → propose plan → `/audit-plan` slot+model routing → lock) then an autonomous Workflow (implement → iterative independent review → fix) for one coding task.

## Contents (file inventory)

| File | What it holds |
|---|---|
| `SKILL.md` | 8-step pre-flight procedure + the Workflow launch contract. Frontmatter: `disable-model-invocation: true`, `allowed-tools: Task, Skill, Workflow`. ~31 lines. |
| `pipeline.js` | The autonomous build Workflow: `EFFORT` tiers, `DEFAULTS` per slot (each carries `agentType` + `model`), `LENS_AXES`, `FINDINGS_SCHEMA`, `resolveSlot()` (per-slot agent+model override + `args` parse-guard), the review→fix loop. ~145 lines. |
| `orchestrate-TDD.md` | Full technical design doc. |
| `orchestrate-AgentRef.md` | This file. |

## Fact table

| Thing | Value |
|---|---|
| Invocation | `/orchestrate <task>` (slash-only; never auto-fires) |
| Pre-flight tools | Explore (Task), grill-me (Skill), plan-primitive-auditor (Task) |
| Launch args | `{ task, plan, effort, agents:{ implement, fix, reviewLenses:[{lens,axis,agentType,model}] } }` — each slot is a bare `"agentType"` string OR a `{ agentType, model }` object. **Pass `args` as a real object, not stringified.** |
| Effort tiers | `quick` (1 lens, 1 round) · `balanced` (3 lenses, ≤2 rounds, default) · `thorough` (3 lenses, ≤3 rounds) |
| Default slots | implement `general-purpose`@`sonnet` · review `code-review-worker`@`sonnet` · fix `general-purpose`@`sonnet` (audit step 5 may swap agent and/or model per slot) |
| Model tiering | step 5 picks `haiku`/`sonnet`/`opus` per slot; reach for `opus` on `implement` + the single highest-risk lens before adding reviewers (model gains > fan-out gains per token) |
| Review lenses | correctness · requirements-fit · quality (flag only what breaks correctness or a stated requirement; evidence required) |
| Loop guard | empty review round ≠ clean (`reviewFailed`); cap at `maxRounds` |

## Where do I find X

- **Swap the agent _or model_ in a slot** → recommended per-task by step 5 (`/audit-plan`); defaults in `pipeline.js` `DEFAULTS` (each slot has `agentType` + `model`); resolution in `resolveSlot()`.
- **Change effort behavior** → `EFFORT` table top of `pipeline.js`.
- **Change what reviewers flag / the axes** → `LENS_AXES` in `pipeline.js`.
- **The "don't over-flag" constraint** → reviewer prompt in the loop + `LENS_AXES` text.
- **Why main-context not `context: fork`** → TDD §3 (no nested subagents; Workflow can't be spawned from a fork).
- **The grill plan-handoff / codebase-first rule** → `SKILL.md` step 3.
- **The args contract** → `SKILL.md` step 7 ⇄ `pipeline.js` arg resolution block.

## Pros

- Review loop is **structural** — the script can't "forget" it (vs methodology-as-instruction).
- **Independent** diverse-lens review — the bake-off's proven quality lever.
- Design ambiguity resolved with the operator **before** any code (grill-me gate).
- **Per-task specialist _and model_ routing** without brittle keyword matching (audit-plan, operator-confirmed) — model tiered per slot, not one global setting.
- **Cost/quality dial** (effort tiers); lean SKILL + version-controlled, swappable pipeline.
- Evidence-required findings + over-flag constraint → less reviewer-induced over-engineering.

## Cons / limitations

- **Not fire-and-forget** — stops to grill you (by design, but a UX cost).
- **Token cost** — multi-agent + iterative loop; `thorough` approaches the bake-off's most-expensive arm.
- **`plan-primitive-auditor` as a slot-router is a purpose-stretch** (it audits plan *steps*, not pipeline *slots*) — closest tool, not purpose-built.
- **Final-round fix is unverified** (no re-review after the last fix) — inherent to a bounded loop.
- Static (no build/test) environments blunt runtime-bug detection (bake-off lesson; confirmed in the live run — UE5 code reviewed, never compiled).

> First run end-to-end **2026-06-22** (TOG `UTOGGA_Counter`) — clears the prior "never run live" / `phase()`-repeat unknowns. A same-task bake-off vs a matched hand-authored dynamic Workflow (same agents + Opus) had `/orchestrate` win an Opus 3-judge panel ~89 vs ~81 — on scope discipline + docs, not raw coding (the code bodies were near-identical). Lesson: the edge is the disciplined locked-plan handoff, not a coding-capability gap.

## Iteration log (what each review caught)

| Ver | Change | `skill-design-reviewer` verdict → fixes applied |
|---|---|---|
| v1 | Baseline: thin launcher skill + Plan→Implement→Review×2→Fix workflow | REVISE FIRST → add `allowed-tools: Workflow`; use `${CLAUDE_SKILL_DIR}` not hardcoded path; cut "When NOT to use" negative-scope section |
| v2 | Inserted `grill-me`: pre-flight became explore→grill→lock; dropped the in-workflow Plan phase (planning moved to grilled pre-flight); `allowed-tools` → `Task, Skill, Workflow` | REVISE FIRST → step 3 must surface the draft plan before invoking grill-me (it takes no args); specify the Explore prompt fields; make the implementer's "already grilled" framing conditional on a real plan |
| v3 | Big expansion: `/audit-plan` slot-router (step 5); axis-specialized review lenses + `evidence` field + over-flag constraint; effort tiers; iterative review→fix loop with empty-round guard; `args.agents` overrides | REVISE FIRST → step 5 must demand a structured slot mapping for `args.agents`; step 5 must pass the plan text in the prompt (not rely on plan-file discovery); trim the "Customizing" prose; forward implementer context to the Fix agent |
| v5 | Blocking fixes applied; not re-reviewed (prescribed one-liners) | Clean; pipeline `node --check` passes |
| v6 | **Current** — first live run surfaced two bugs, both fixed: audit step 5 picks **model + agent** per slot; `pipeline.js` `resolveSlot()` honors a `{agentType,model}` slot (string still = default model) and reports `agentType@model`; `args` parse-guard so a stringified payload no longer collapses to defaults | Shipped to `claude-kit` main as **PR #16** (2026-06-22) |

(Versions are by review round; v4→v5 was the application of v3's review fixes; v6 is the post-live-run fix pass.)

## Origin

Built 2026-06-21 from the three-arm superpowers bake-off (`references/superpowers-bakeoff-2026-06.md`): the dynamic-Workflow-with-independent-review arm won on quality, the curated-kit arm on efficiency, the superpowers methodology arm came last. `/orchestrate` fuses the winners — deterministic Workflow structure + curated kit specialists.
