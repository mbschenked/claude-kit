---
name: tdd-generator
description: Analyze a codebase — especially a UE5 C++/GAS game — and emit an architecture-first Technical Design Document in one disciplined, read-only pass: survey modules/systems, resolve unknowns by reading the code (not by asking), verify every number against the source, and write the TDD with no-fabrication / [UNVERIFIED] / [ASSUMED] / [OPEN] discipline.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob
---

# tdd-generator — codebase → Technical Design Document

Produce an **architecture-first TDD** from a codebase in one structured, read-only pass. You read the code and emit the document as your response; the caller writes it to disk.

## Lineage

**Document discipline** is inherited from the `design-doc` skill: no fabricated decisions, `[ASSUMED]`/`[OPEN]` tagging, preserve disagreement, final reader-test. **Codebase-first gap-filling** (resolve unknowns by reading the code, not by asking) is borrowed from Matt Pocock's `grill-me` method, applied as a single internal pass. The **verification discipline** (Step 4) is the load-bearing hardening — it targets the no-fabrication failure mode where a generator restates a source/architecture doc's unverified counts as facts.

## Step 1 — survey the codebase

Detect the project type first, then extract.

**Unreal Engine path** (a `*.uproject` exists). Use the bundled checklist `references/unreal-gas-extraction-checklist.md` and pull:
- **Modules & build:** parse `*.uproject` (engine version, plugins) and every `*.Build.cs` (the `Public/PrivateDependencyModuleNames` dependency graph). Map module layering.
- **GAS surface:** `UAbilitySystemComponent` setup; `UGameplayAbility` subclasses (active/passive); `UAttributeSet` + attributes; `UGameplayEffect` + any `UGameplayEffectExecutionCalculation`; `GameplayTags` taxonomy; `UAbilityTask` usage; `GameplayCues`.
- **Actor/Component model:** `ACharacter`/`APawn` subclasses, component composition, `GameMode`/`GameState`/`PlayerController` flow.
- **Input & AI:** EnhancedInput (InputActions/MappingContexts/InputTags); BehaviorTree/Blackboard topology.
- **Data:** DataTables / DataAssets that drive behavior, and the row structs behind them.

**Generic path** (no `*.uproject`). Identify languages, top-level modules/packages, entry points, the build/test commands, the dependency graph, and the dominant architectural pattern.

Read enough real files to ground every claim. Prefer reading code over inferring.

## Step 2 — resolve the gaps (codebase-first, single pass)

Walk the open questions the survey raised. For each: if it can be answered by reading the code, read the code and answer it. Only what genuinely cannot be settled from the code becomes an `[OPEN]` item. Do **not** invent a decision to fill a gap.

## Step 3 — emit the TDD (this template, in order)

This template is the single source of truth — use it verbatim in this section order:

```
# <Project> — Technical Design Document

## 1. One-liner / executive summary
   What this system is and the single most important structural fact about it. If the
   input doesn't support a sharp summary, write the best version and tag it [ASSUMED].

## 2. Goals & non-goals
   - Goals: bulleted, each independently checkable.
   - Non-goals: explicitly out of scope.

## 3. System architecture   ← LOAD-BEARING; give it the most room
   The real structure. Sub-section per major system. Include:
   - module / dependency map
   - the central control + data flow (the "spine" of the system)
   - component / ability stack (for GAS: who owns what, what is shared)
   - an ASCII or described diagram of the core loop

## 4. Key technical decisions   (ADR style)
   Each: the decision · the one-line why · the alternative not taken.
   Pull these out even when the code only implies them.

## 5. Data model & DataTables
   Row structs, data assets, and what behavior they drive. Schemas, not prose.
   Counts/rows here MUST be verified against the source (Step 4) or tagged [UNVERIFIED].

## 6. Performance & budgets
   A MEASUREMENT PLAN — what to measure, where, and against what target-setting process.
   Do NOT invent FPS / memory / draw-call numbers the code doesn't state. If the code or
   config states a budget, cite it; otherwise this section is the plan to establish them,
   not a table of guessed figures.

## 7. Risks / unknowns
   What could make this wrong or hard. Honest, not pro forma.

## 8. Open questions
   Phrased as questions, each tagged [OPEN]. The gaps, surfaced.

## 9. Next steps
   Imperative, ≤6 items, ordered by what unblocks the most.

## Appendix — Unreal/GAS extension
   GAS-specific mappings (component → ability/effect/tag), notify/cue catalog,
   input-tag → ability bindings. Omit for non-Unreal projects.
```

Drop a section only if the codebase genuinely has nothing for it — leave the heading with `*(not present in codebase)*` so the gap is visible.

## Step 4 — ground, verify, and gap-flag (the discipline)

- **No fabricated decisions.** Unsettled → §8 `[OPEN]`, never invented into §3/§4 as if decided.
- **Never restate a number you did not verify.** Any count, quantity, or inventory figure (number of abilities, EQS queries, anim notifies, BT nodes, DataTable rows, attributes) must either be (a) confirmed by reading the source/assets and cited with the file you counted, or (b) tagged `[UNVERIFIED]`. If a reference/architecture doc asserts a count, do **not** repeat it as fact — re-derive it from the code/data (e.g. grep the type and count, or read the DataTable rows directly), or quote it as "reference asserts N — `[UNVERIFIED]`". This is the single highest-leverage rule: restated-but-unverified numbers read as fabrications.
- **Budgets are a plan, not invented numbers.** Per §6 above: a measurement plan unless the code/config states a real figure.
- **Demote inferred tables.** Any table whose values are inferred, sampled, or "directionally corrected" rather than read from source (e.g. a tuning curve) is `[OPEN] — re-sample`, not a filled table presented as data.
- **Tag inferred connective tissue** `[ASSUMED]` so the reader sees where you bridged.
- **Preserve disagreement.** If the code shows two competing approaches, record the tension; don't pick a winner.
- **Cite the code.** Every architectural claim should be traceable to a real file/type (path, and line where it matters). Verify cited line numbers.
- **Reader-test §1 and §3** as someone with zero context before delivering: any undefined actor/system/term gets defined or flagged.
- **Tighter is better.** A higher-fidelity doc is *more verified and shorter*, not longer. Don't restate the same gap across sections; one canonical registry (§8). Don't pad deferred or not-yet-built systems to look exhaustive.

## Guardrails

- **Read-only.** No Write/Edit/Bash; emit the TDD as your response (the caller writes it to disk).
- **Markdown only**, diff-able, kit-consistent.
- **Gaps visible, not filled.** `[OPEN]`/`[ASSUMED]`/`[UNVERIFIED]` markers are a feature, not a failure.
- **Don't reproduce this template from memory** when the skill wasn't invoked.

## Companion

Score the output with the `unreal-design-doc-reviewer` subagent (UE5/GAS) or `design-doc-reviewer` (general) — both return a 0–100 fidelity score against the codebase and an optional ground-truth doc.
