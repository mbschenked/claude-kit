---
name: tdd-generator-hybrid
description: Generate an architecture-first Technical Design Document from a codebase (esp. UE5 C++/GAS) by combining Matt Pocock's interrogation front-end with the kit's documentation back-end — grill the code (decision-tree, codebase-first) + build a domain glossary + sketch testing seams, then emit our architecture-first TDD template under design-doc's no-fabrication / [ASSUMED] / [OPEN] discipline. "Variant C" (the blend) of the TDD-generator bake-off (siblings: tdd-generator-ours, tdd-generator-pocock).
disable-model-invocation: true
allowed-tools: Read, Grep, Glob
---

# tdd-generator-hybrid — codebase → TDD, best of both (Variant C)

Variant C bolts Pocock's interrogation front-end onto the kit's architecture-first back-end.

**Attribution:** front-end method from `mattpocock/skills` @ `aaf2453` (`_vendor/pocock/SOURCE.md`); back-end discipline + template from the kit's `design-doc` skill and `tdd-generator-ours`. Wording original. (The rationale for this blend — and whether it wins the bake-off — lives in the comparison write-up under `GameMakerKit/analysis/`, not here.)

## Phase 1 — grill the codebase (Pocock front-end)

Interrogate the system relentlessly, decision tree branch by branch, resolving dependencies between decisions. For each open question, state a recommended answer. **If a question can be answered by reading the codebase, read it** — that's the primary path (non-interactive). Use the bundled Unreal field guide when a `*.uproject` exists:

→ `references/unreal-gas-extraction-checklist.md` (shared with `tdd-generator-ours`) — modules/Build.cs graph, the full GAS surface (ASC, abilities, attributes, effects/ExecCalcs, tags, tasks, cues), actor/component model, EnhancedInput, animation-as-logic, AI, DataTables.

Generic codebases: identify languages, modules, entry points, build/test, dependency graph, dominant pattern.

## Phase 2 — domain + seams (Pocock middle)

- **Glossary:** the canonical domain terms and their one precise meaning; sharpen overloaded terms; surface code↔term contradictions. (Derived read-only; appended to the doc, not written to the repo.)
- **Testing seams:** note where the system is/should be tested — prefer existing seams, highest seam possible. This feeds the TDD's risk/next-steps and an explicit Testing section.

## Phase 3 — emit our architecture-first TDD (kit back-end)

Synthesize (do not interview). Write the TDD in this section order — our template, with a Testing section grafted in from Pocock's seam analysis:

```
# <Project> — Technical Design Document

## 1. One-liner / executive summary
   What this system is + the single most important structural fact. [ASSUMED] if unsupported.

## 2. Goals & non-goals
   Goals (each independently checkable) · Non-goals (explicitly out of scope).

## 3. System architecture   ← LOAD-BEARING, most room
   Real structure, sub-section per major system: module/dependency map · the central
   control + data flow (the spine) · component/ability stack (GAS: who owns what, what's
   shared) · a described/ASCII diagram of the core loop.

## 4. Key technical decisions   (ADR style)
   Each: decision · one-line why · alternative not taken. ADR only when the decision is
   hard to reverse, surprising, and a real trade-off (Pocock's bar).

## 5. Domain model & data
   Glossary (canonical terms) · DataTables/DataAssets + row structs and the behavior they drive.

## 6. Testing strategy
   The seams (highest preferred) · what makes a good test here (external behavior) · prior art.

## 7. Performance & budgets
   Targets/hot paths if discoverable; [OPEN] if the code doesn't state them.

## 8. Risks / unknowns
   What could make this wrong or hard. Honest.

## 9. Open questions
   Questions, each tagged [OPEN].

## 10. Next steps
   Imperative, ≤6, ordered by what unblocks the most.

## Appendix — Unreal/GAS extension
   Component → ability/effect/tag mappings, notify/cue catalog, input-tag → ability bindings.
   Omit for non-Unreal projects.
```

Drop a section only if the codebase genuinely has nothing for it — leave the heading with `*(not present in codebase)*`.

## Phase 4 — ground & gap-flag (design-doc discipline)

- **No fabricated decisions.** Unsettled → §9 `[OPEN]`, never invented into §3/§4 as decided.
- **Tag inferred bridging** `[ASSUMED]`.
- **Preserve disagreement;** don't pick a winner the code doesn't.
- **Cite the code** — every architectural claim traceable to a file/type.
- **Reader-test §1 and §3** with zero context before delivering.

## Guardrails
- **Read-only.** Emit the TDD as your response.
- **Markdown only**, diff-able. Gaps visible (`[OPEN]`/`[ASSUMED]`), not filled.
- **Explicit-invoke only.**
