# Vendored method reference — Matt Pocock's `skills`

**Source repo:** https://github.com/mattpocock/skills
**Pinned commit:** `aaf2453fbdfe7a15c07f11d861224f34ab4b53cb` (2026-05-31)
**Fetched:** 2026-06-04
**License:** NOT DECLARED upstream as of the pinned commit. Because no license grants redistribution, this directory does **not** store his SKILL.md files verbatim. It records attribution, source URLs, and a paraphrase of each skill's *method* so `tdd-generator-pocock` (Variant B of the TDD bake-off) can reproduce his pipeline faithfully and offline. If you confirm a permissive upstream license, you may vendor the originals verbatim instead. Do not publish copies of his text until then.

This is the basis for **Variant B** in the bake-off — his method, adapted to "produce a TDD from a codebase," in our own wording.

---

## The pipeline we reproduce: `grill-me → grill-with-docs (domain) → to-prd`

### `grill-me` — codebase-first decision-tree interrogation
URL: https://github.com/mattpocock/skills/blob/main/skills/productivity/grill-me/SKILL.md
Method (paraphrased): interrogate every aspect of a plan/design relentlessly until shared understanding; walk down each branch of the design tree, resolving dependencies between decisions one at a time; for each question give a recommended answer; **one question at a time**; and crucially — *"if a question can be answered by exploring the codebase, explore the codebase instead."* (This last rule is what lets it run non-interactively in an automated bake-off: unknowns get resolved by reading code rather than by asking a human.)

### `grill-with-docs` — domain awareness (CONTEXT.md glossary + ADRs)
URL: https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md
Method (paraphrased): the same relentless interview, plus during codebase exploration look for/maintain a domain glossary `CONTEXT.md` (a pure glossary — no implementation detail) and `docs/adr/` Architecture Decision Records. Challenge the user's terms against the glossary; sharpen fuzzy/overloaded language to precise canonical terms; stress-test domain relationships with concrete edge-case scenarios; cross-reference claims with the code and surface contradictions; capture resolved terms into `CONTEXT.md` inline. Offer an ADR only when a decision is (1) hard to reverse, (2) surprising without context, and (3) the result of a real trade-off.

### `to-prd` — synthesize into a fixed template (no interview)
URL: https://github.com/mattpocock/skills/blob/main/skills/engineering/to-prd/SKILL.md
Method (paraphrased): take the conversation context + codebase understanding and *synthesize* a PRD (do not interview). Steps: (1) explore the repo, use the domain glossary vocabulary, respect existing ADRs; (2) sketch the **testing seams** — prefer existing seams, use the highest seam possible, propose new ones at the highest point; (3) write the PRD from his template and (in his flow) publish it to the issue tracker with a `ready-for-agent` label.
His PRD template sections: **Problem Statement → Solution → User Stories** (a long, exhaustive numbered list, "As an <actor>, I want <feature>, so that <benefit>") **→ Implementation Decisions** (modules, interfaces, architectural decisions, schema/API contracts; *no file paths or code snippets* except a decision-encoding snippet from a prototype) **→ Testing Decisions** (what makes a good test = external behavior not implementation; modules to test; prior art) **→ Out of Scope → Further Notes**.

---

## Adaptations made for Variant B (`tdd-generator-pocock`)
1. **Non-interactive.** The bake-off runs this as an autonomous agent with no human to grill, so `grill-me`'s "explore the codebase instead" rule becomes the *primary* gap-resolution path; only genuinely unresolvable items are flagged.
2. **No publishing.** Drop `to-prd`'s "publish to issue tracker / apply `ready-for-agent` label" — we emit the document as the response; the caller writes it.
3. **Output shape kept as his.** Variant B intentionally keeps his **PRD template** rather than our architecture-first TDD template — the bake-off's job is to test whether his PRD-oriented method captures an *architecture* TDD as well as a purpose-built one. (Variant C is where we blend.)
4. **Read-only.** `CONTEXT.md`/ADRs are *derived in-doc* (as an appendix), not written to the target repo, since the generator is read-only analysis.
