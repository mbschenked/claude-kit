---
name: tdd-generator-pocock
description: Generate a design document from a codebase by faithfully reproducing Matt Pocock's skills pipeline — grill-me (codebase-first decision-tree interrogation) → domain awareness (CONTEXT.md glossary + ADRs) → to-prd (synthesize into his fixed PRD template). Adapted to run non-interactively (resolves unknowns by reading code, not by asking) and read-only (emits the doc, no publishing). Keeps his PRD-shaped output on purpose. "Variant B" of the TDD-generator bake-off (siblings: tdd-generator-ours, tdd-generator-hybrid).
disable-model-invocation: true
allowed-tools: Read, Grep, Glob
---

# tdd-generator-pocock — codebase → design doc, the Pocock method (Variant B)

This is **Variant B** of the TDD bake-off: a faithful reproduction of **Matt Pocock's `skills` pipeline**, adapted for autonomous, read-only codebase analysis. Its output is intentionally **PRD-shaped** (his template), not our architecture-first TDD template — the bake-off exists to test whether his method captures an architecture doc as well as a purpose-built generator. Do not "fix" it toward our template; that's Variant C's job.

**Attribution:** method from `mattpocock/skills` @ `aaf2453` (see `_vendor/pocock/SOURCE.md` for source URLs, license note, and the adaptations made). Wording here is original; the method is his.

## Phase 1 — grill (codebase-first, non-interactive)

Interrogate every aspect of the system relentlessly until you reach a coherent understanding. Walk down each branch of the design tree, resolving dependencies between decisions one at a time. For each open question, state your **recommended answer**.

The load-bearing rule: **if a question can be answered by exploring the codebase, explore the codebase instead of asking.** Because this runs without a human in the loop, that is the *primary* path — read the code (Read/Grep/Glob) to resolve each branch. Only questions that genuinely cannot be settled from the code survive as open items for Phase 3.

## Phase 2 — domain awareness (glossary + decisions)

While exploring, build an in-document **domain model** (Pocock's `grill-with-docs` discipline), derived read-only — do not write files into the target repo:

- **Glossary (CONTEXT.md-style):** the canonical domain terms and exactly what each means. Pure glossary — no implementation detail. Sharpen fuzzy/overloaded terms to one precise meaning ("does 'account' mean the Customer or the User?"). Where the code contradicts an apparent term meaning, surface the contradiction.
- **ADRs (sparingly):** record a decision as an ADR only when all three hold — (1) hard to reverse, (2) surprising without context, (3) the result of a real trade-off. Otherwise skip it.

Use this vocabulary consistently throughout the document.

## Phase 3 — to-prd (synthesize into his template)

Do **not** interview — synthesize what you now know. Before writing:
- Use the project's domain glossary vocabulary throughout; respect any ADRs in the area.
- **Sketch the testing seams:** where would this be tested? Prefer existing seams; use the **highest seam possible**; if new seams are needed, propose them at the highest point.

Then write the document using **his PRD template**, verbatim in structure:

```
## Problem Statement
   The problem being solved, from the user's perspective.

## Solution
   The solution, from the user's perspective.

## User Stories
   A LONG, exhaustive numbered list. Each: "As an <actor>, I want a <feature>, so that <benefit>."
   Cover all aspects of the system.

## Implementation Decisions
   Modules built/modified · their interfaces · architectural decisions · schema changes ·
   API contracts · specific interactions. NO file paths or code snippets (they go stale) —
   exception: a single decision-encoding snippet (state machine / reducer / schema / type shape)
   if prose can't capture it as precisely.

## Testing Decisions
   What makes a good test (test external behavior, not implementation details) · which modules
   get tested · prior art (similar tests already in the codebase).

## Out of Scope
   What this document explicitly does not cover.

## Further Notes
   Anything else relevant.
```

## Appendix (Pocock-method artifacts)
Append the derived **Glossary** and any **ADRs** from Phase 2 here (since we're read-only and don't write them into the repo).

## Adaptations from upstream (do not undo)
- **Non-interactive:** unknowns resolved by reading code, not by asking. ← enables autonomous bake-off runs.
- **No publishing:** emit the doc as your response; skip the "publish to issue tracker / `ready-for-agent` label" step.
- **Read-only:** glossary/ADRs are derived in the doc's appendix, never written to the target repo.

## Guardrails
- **Read-only.** No Write/Edit/Bash; emit the document as your response.
- **Stay faithful to the method.** Keep his PRD template and his testing-seam emphasis. If you find yourself reaching for our architecture-first TDD template, stop — that's Variant C.
- **Explicit-invoke only.**
