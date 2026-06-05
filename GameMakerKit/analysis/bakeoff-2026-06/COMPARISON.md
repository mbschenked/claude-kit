# TDD Generator Bake-off — Comparison & Recommendation

**Target:** `/Users/mbschenk/ClaudeCode/references/TOG-Remake` (UE 5.7 C++/GAS)
**Ground truth:** `docs/TOG-GAS-Architecture.md`
**Scored by:** independent, critical-by-default critics (`unreal-design-doc-reviewer`), 5 axes, weighted overall.
**Run:** 78 agents · ~6.0M tokens · ~67 min · 2026-06-04→05.

## Final scores

| Rank | Variant | Final | Trajectory | Iterated |
|---|---|---|---|---|
| 🥇 | A — ours (kit-native) | **93** | 82 → 89 → 93 → 93 | 4 rounds |
| 🥇 | C — hybrid (blend) | **93** | 76 → 93 → 91 → 93 | 4 rounds |
| 3 | B — Pocock-adapted | 80 | 80 | no |
| 4 | E — technical-writer baseline | 79 | 79 | no |
| 5 | D — Pocock verbatim (control) | 78 | 78 | no |

Round-0 per-axis (non-iterated group): `gas-accuracy` 90–95 everywhere; `architecture-fidelity` 62–68 — the axis that decided the bake-off.

> **Data caveat:** the raw workflow output recorded `finalOverall: 0` for A and C — a tail-of-run scoring failure in round 4 (all critics returned null), and a loop bug that let that null round overwrite the good score. Both genuinely **peaked at 93**. The iterate loop is now fixed (best-score tracking; a failed round can't clobber a good one). Only A and C were iterated because the loop iterates the round-0 leader (A) plus the hybrid (C).

## Pros / cons

### A — ours (kit-native) · **93** · ✅ recommended
- **Pros:** top score; architecture-first template captures the load-bearing structure (shared attack-execution core, the `AC_ParryAttackV2` parry/counter/finisher keystone, animation-as-logic, two-trigger front-ends); no external dependency; simplest to maintain.
- **Cons:** verbose (~14k words); needed 2 iteration rounds to reach 93; plateaued there.

### C — hybrid (blend) · **93** · tie, not worth the complexity
- **Pros:** matched A's 93; reached 93 fastest (round 1); Pocock's interrogation front-end is theoretically the stronger "understand the system" step.
- **Cons:** **no score advantage over A**; more moving parts (depends on vendored Pocock method); largest doc (~15k words); score bounced (93→91→93) rather than climbing smoothly.

### B — Pocock-adapted · 80
- **Pros:** cleanest, most concise output (~4.8k words); highest `no-fabrication` (96) — his "synthesize, don't invent" discipline shows; strong `gas-accuracy` (93).
- **Cons:** PRD shape (Problem/Solution/User Stories) under-captures *architecture* — `architecture-fidelity` 68; not built for system-structure docs.

### E — technical-writer baseline · 79
- **Pros:** strong generic doc with zero special method; best `actionability` of the non-iterated group (86); highest `gas-accuracy` (95).
- **Cons:** lowest-tier `architecture-fidelity` (62); no system-structure framing.

### D — Pocock verbatim (control) · 78
- **Pros:** good `completeness` (81) and `actionability` (88); proves his unmodified skills are competent out of the box.
- **Cons:** lowest overall; PRD shape mismatched to the task; ~+2 below my adaptation (B) — i.e. adapting his skills barely moved the needle.

## Conclusions (honest)

1. **Method beats no-method by ~13 pts** — but only the *right* method. Architecture-first (A/C) ≫ PRD-shaped (B/D/E) for an architecture TDD.
2. **A ≈ C — no real difference.** The hybrid's Pocock front-end did not beat plain ours. Per the "no-difference-is-fine" rule, **A wins on simplicity**.
3. **Pocock's skills aren't worse software** — they're built for feature PRDs, and they performed exactly like a strong generic tech writer on this *architecture-extraction* task (B≈D≈E). His `no-fabrication` discipline (96) is genuinely worth stealing — and Variant A already encodes the same `[ASSUMED]`/`[OPEN]` rule.
4. **95 not reached.** Both leaders plateaued at 93 against a deliberately critical reviewer. 93 here is a strong result; the last 2 points are hard architecture-fidelity items (see each round's "top gaps").

## Recommendation

**Keep `tdd-generator-ours` (Variant A) as the standing TDD generator.** Retire the hybrid and the two Pocock variants to `_candidates`/reference (the verbatim copies stay gitignored). Adopt `unreal-design-doc-reviewer` as the quality gate. If you later want to chase ≥95, the cheapest lever is feeding the round-3 critic "top gaps" back into Variant A's template as required sections.

## Artifacts
- Five rendered TDDs + this comparison: `GameMakerKit/analysis/bakeoff-2026-06/`
- Visual report (open in a browser): `tdd-bakeoff-report.html`
- Raw per-variant markdown: `tdd-{A-ours,C-hybrid,B-pocock,E-baseline-techwriter,D-pocock-verbatim}.md`
