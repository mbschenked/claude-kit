# The 5 Variants — Pros / Cons, Why 93, and What Would've Made Them Better

Source: five **independent** reviewers (one per doc, blind to prior scores), each scoring the generated TDD against the real `TOG-GAS-Architecture.md` and the actual code — plus my own judgment layered on top. Independent scores tracked the bake-off closely (biggest move: verbatim Pocock fell 78→71 on a fresh read).

| Variant | Independent | Read in one line |
|---|---|---|
| C — hybrid | **92** | The most code-verified of the architecture-first docs; edges A by noise. |
| A — ours | **91** | Same class as C; the recommended keep (simpler, no dependency). |
| B — Pocock-adapted | **80** | Beautiful, concise PRD; misses most of the reference's architecture. |
| E — baseline (technical-writer) | **79** | Excellent as-built scaffold description; no architectural altitude. |
| D — Pocock verbatim | **71** | His raw skills = a forward build plan, not architecture extraction. |

---

## A — ours (kit-native) · 91
**Pros**
- Every code claim spot-checked was true and precisely cited (ExecCalc is an unrolled Physical+Fire sum, asymmetric health/poise SetByCaller gates, `GetScriptStruct` returns the derived struct, `TryActivateAbility` only in the Held handler).
- Rigorously honest BUILT-vs-`[INTENDED]` boundary — correctly states no AbilityTask exists, `FTOGComboRow` has no consumer, `Die()` is a stub.
- Nails the reference's #1 finding (one shared attack core, two trigger front-ends) and the keystone data fact (counter/finisher share one payload, differ by `InstaKill?`), with the right "make TOG *with* GAS" north star.
- Catches subtleties the reference glosses (re-entrancy guards, pure-poise hits sending no reaction event).
- Corrects the reference where code disagrees (uses registered `State.ParryWindow`).

**Cons**
- Forwards the reference's **unverified counts** (8 EQS, 44 notifies, 28 BT nodes, 6 rows) as fact-shaped tables — it flags "re-verify at build," but they still read as load-bearing facts.
- The Performance & Budgets section is admitted straw-men — the one ungrounded section.
- Poise-regen curve carried from the reference (which says values are "inferred, not re-measured").
- Minor line-citation drift (cites lib `:160/168`, actually `:161–169`).
- Long, with `[INTENDED]` systems re-narrated at volume.

## C — hybrid (blend) · 92
**Pros**
- **Best citation discipline in the bake-off** — every load-bearing claim carries a verified file:line.
- Surfaces code-level reasons the reference lacks (the `UAnimNotify` vs `UAnimNotifyState` base-class mismatch is *why* the sweep is unbuilt; `DamageType` vs `DamageTypeTag` field distinction).
- Reproduces the reference's own internal contradiction (UI named two ways) and elevates it to an explicit `[OPEN]` ADR instead of silently picking.
- Distinguishes the *wired* victim route (`SendGameplayEventToActor`) from the reference's *named* model — a precise, non-obvious fidelity point.

**Cons**
- Presents a full 11-point poise-regen curve **table** as data, then admits it's inferred/unmeasured — its one real groundedness wobble.
- Largest doc (~880 lines) with heavy cross-section repetition — same gaps restated 3–4×.
- A few perf budgets tagged `[DERIVED]` overstate grounding (closer to genre guesses → should be `[PROPOSED]`).
- "44 notifies" used as a code-relevant figure but it's reference-sourced, not code-verified.

## B — Pocock-adapted · 80
**Pros**
- Highest `no-fabrication` (97) — his "synthesize, don't invent" discipline is real.
- Cleanest, most concise (~4.8k words); the reducer-shaped damage spine matches `PostGameplayEffectExecute` almost line-for-line.
- Unusually strong Testing Decisions — ranks seams highest-first, each mapped to a docket risk.
- Well-chosen ADRs with genuine trade-offs.

**Cons**
- Misses the reference's #1 finding (shared attack core, two triggers) — framed only as a generic montage→event→damage flow.
- Drops the **cross-actor reaction pairing** (the "defining aesthetic" — synchronized attacker/victim exchange) → treats reaction-montage choice as opaque BP content.
- Relegates the parry/counter/finisher **keystone** to a two-line "Out of Scope" bullet.
- No poise *economy*, no AI feedback loop, no BT port.

## E — baseline (technical-writer) · 79
**Pros**
- Near-flawless as-built description of the C++ scaffold; `gas-accuracy` 95.
- Correctly extracts the Max-before-current modifier-ordering contract and elevates it to a risk.
- Exact module/build claims (TOGCore→TOG dep direction, plugin list, build settings).
- Accurate end-to-end hit data-flow trace.

**Cons**
- Misses the parry keystone, poise economy, and the entire enemy-AI/BT port (reference treats all as core).
- "59 source files" overcount (actual 55) stated as fact.
- Animation-as-logic reduced to just `AN_MontageEvent`; the ANS-window/curve taxonomy is absent.
- Documents what the scaffold *is*, not what the system is *becoming* — no design altitude.

## D — Pocock verbatim (control) · 71
**Pros**
- Relentlessly code-grounded (the grill-me "resolve by reading code" discipline shows) and highly actionable — D1–D4 executable directly.
- Open-decisions docket matches `REVIEW-DOCKET.md` verbatim; honest about missing `Config/`/`Content/`.

**Cons**
- One clean **factual error**: claims "19 native gameplay tags"; the code declares **22**.
- Lowest architecture-fidelity (58) — his PRD template reframes the task as a forward build slice (D1–D6) and parks the keystone, poise economy, and AI loop as future phases.
- Reads as "what to build next," not "what the system fundamentally is."

---

## Why the leaders scored ~92–93 (not higher)
Three ceilings, consistent across reviewers:

1. **They were *too faithful to the reference doc* on no-fabrication (88).** Both forwarded the reference's own un-enumerated counts (8 EQS, 44 notifies, 28 BT nodes, 6 DataTable rows) and its inferred poise-regen curve **as fact-shaped tables**. The reviewer rubric treats restated-but-unverified numbers as a fabrication risk — even when hedged. Ironically, the winners lost points for trusting the ground-truth doc instead of re-deriving from code/assets.
2. **One genuinely ungrounded section each** — Performance & Budgets is straw-man numbers (no in-repo source). A whole section with no ground truth caps completeness/substance regardless of how well it's labeled.
3. **Fidelity was "captured from the doc," not "independently verified."** Much of the deferred half (`[INTENDED]` systems) faithfully restates the reference rather than confirming it against the original UE5.4 game. That's "captured," not "confirmed" — short of the ≥95 "miss nothing AND verify it" bar.

Plus minor drag: line-citation drift, and length/redundancy (≈880 lines, gaps restated 3–4×) — signal dilution, not wrong content.

## What would've pushed them to ≥95
1. **Never restate a number you didn't verify.** Demote the inherited counts out of fact tables into one bracketed "reference asserts — UNVERIFIED" callout, or re-inventory them against the 5.4 data dumps and cite those.
2. **Kill the straw-man budgets.** Replace invented FPS/memory figures with a *measurement plan* only (or genre-cited ranges with sources).
3. **Demote the poise-regen curve** from a filled 11-point table to an `[OPEN] — re-sample at build` placeholder.
4. **Independently verify the EQS / DataTable rows** against `docs/planning/tog-data-dump/` and cite them — converts reproduced-design into verified-fact on the heaviest axis.
5. **Tighten.** Collapse the repeated gap-restatements to one canonical registry; fix the line-number drift. A 95 doc is *more verified and shorter*, not longer.

## My bottom-line judgment
- **A and C are the same quality** (91 vs 92 = noise). C's Pocock front-end bought marginally better citation discipline but cost length and a dependency. **Keep A.**
- **My Pocock adaptation (B, 80) genuinely beat his verbatim skills (D, 71) by ~9 pts** on the independent pass — bigger than the bake-off showed. Making grill-me non-interactive + keeping the no-fabrication discipline mattered. But neither closes the architecture-altitude gap, because the PRD template is built for *feature specs*, not *system architecture*.
- **The real lesson isn't "ours beats Pocock"** — it's that **architecture-first templating + grounding discipline** is what an architecture TDD needs, and Pocock's skills are excellent at the different job they're designed for. Steal his `no-fabrication` rigor (97!); keep our template.
- **The fix to reach 95 is a template rule, not more iteration:** add "never restate an unverified count; tag it `[UNVERIFIED]`" and "budgets = measurement plan, not invented numbers" to `tdd-generator-ours`. Cheap, and it attacks the exact axis (no-fabrication) that capped both leaders.
