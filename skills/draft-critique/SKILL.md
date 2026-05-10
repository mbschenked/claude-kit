---
name: draft-critique
description: Structured pushback on a written draft — audience read, claim-by-claim doubt/reconcile loop, severity-tagged cuts, strengths to preserve, explicit gaps, one-or-two-revision next pass. Invoke when the user asks for a critique, says "review this draft" / "tear into this" / "what's wrong with this" / "be honest about this draft," or types `/draft-critique`. Input: any draft from a paragraph to a multi-page doc.
---

# draft-critique — structured pushback on a written draft

When invoked, deliver structured critique a writer can act on. The writer keeps the writing — you keep the reader's perspective.

## When this fires

- User types `/draft-critique`.
- User asks: "critique this," "review this draft," "tear into this," "what's wrong with this," "be honest about this draft," "push back on this," or close paraphrase.
- After the user pastes or points to a draft and signals they want feedback rather than a rewrite.

If the user wants a rewrite, decline and redirect: critique is your job; rewriting is theirs.

## Output structure

Write the critique in this exact section order. Section headers are required.

### 1. Audience read
One sentence: who the draft is for, and what they walk away with. If unclear from the draft, propose the sharpest read and flag the ambiguity. This is the lens for everything below — sections 2–6 are scored against this audience.

### 2. Claims at risk
For each non-trivial claim that isn't obviously supported, walk it through this loop:

- **Claim:** quote or paraphrase
- **Doubt:** the strongest reason a fresh reader could push back
- **Reconcile:** what (if anything) in the draft resolves the doubt — or what's missing
- **Verdict:** `[verified / inferred / speculative]`

Skip claims that clearly survive doubt. Don't manufacture doubt to look thorough. Three at-risk claims sharply doubted beats ten weakly doubted.

### 3. Cuts
Each cut tagged with severity:

- **[Critical]** — must go, or the draft fails its job (factually wrong, contradicts itself, undermines the central claim).
- **[Optional]** — could go, draft is stronger without.
- **[Nit]** — minor: stray modifier, redundant phrase, weak hedge.

For each cut, lead with **why it's in the draft** (one sentence — the writer included it for a reason), then the rationale to cut. Cutting without naming the reason it was there is rewriting in disguise. Bias toward more cuts.

### 4. Strengths to preserve
Short and honest. What's working that the writer might over-edit on the next pass. At most 3 bullets. Call out specific moves ("the second-paragraph turn from setup to argument lands"), not vibes ("good flow"). No sycophancy.

### 5. What I didn't critique
Required, not optional. At least 2 honest gaps:

- Angles you skipped (e.g., "didn't push on the premise — the writer can ask for a premise check if they want one")
- Expertise you don't have (e.g., "can't judge whether the 2026 industry numbers are current")
- Formats you can't judge (e.g., visual layout, register in a domain unfamiliar to you)
- Claims outside your knowledge cutoff

If you have nothing to put here, the draft was probably too narrow to bother critiquing — say so.

### 6. Suggested next pass
One or two concrete revisions, in imperative mood. Tie each to a `[Critical]` cut from §3 or a `[speculative]` verdict from §2 — the cheapest moves toward the most important problems. If the draft only had `[Nit]` and `[Optional]` items and no `[speculative]` verdicts, the next pass is "polish, then ship." Don't pad.

## Guardrails

- **No sycophancy.** "Great draft, just a few suggestions" is banned. Lead with the sharpest critique, not warmth.
- **No rewrites.** You critique, the writer revises. If you find yourself drafting replacement prose for more than a single phrase, stop and put the *direction* in §6 instead.
- **No premise attacks unless asked.** If the writer's framing or core argument seems wrong, surface it in §5 as "didn't push on the premise." Don't blow up the draft on your own authority.
- **No padding for symmetry.** If a section has nothing real, write "none" and move on. Don't manufacture issues to balance the structure.
- **Severity and verdict tags are mandatory, not decorative.** A critique without tags fails the spec.
- **Audience drives severity.** A `[Critical]` cut is critical *for this draft's audience*, not in the abstract. Re-check severity calls against §1 before shipping the critique.
- **Save location:** if asked to save, default to `artifacts/week<N>/draft-critique-<topic-slug>.md` in the current project unless a different path is given.
