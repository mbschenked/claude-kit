---
name: design-doc
description: Turn messy input (meeting transcripts, rough notes, voice-memo text, scattered Slack threads, photographed-doc text) into one structured markdown design document / GDD in a single pass.
disable-model-invocation: true
allowed-tools: Read
---

# design-doc — messy input → structured design document, single pass

This skill is **deliberate, not ambient.** It only runs when the user explicitly invokes it (`/design-doc` or "run the design-doc skill" / "turn this into a design doc"). It will not auto-trigger on the word "design." That is intentional: a design doc is a considered artifact, not something to generate reflexively. It is also the curriculum's reusable `design-doc-template` — later work specs through this.

## Lineage

Adapted from Anthropic's `anthropics/skills` `doc-coauthoring` skill. **Kept:** accept shorthand / stream-of-consciousness input without making the user pre-organize it; build the document section by section; close the gap between what the user knows and what's written down. **Changed:** `doc-coauthoring` is an always-on, interactive, three-stage back-and-forth (context-gather → refine → fresh-instance reader-test). This is one explicit pass — gather what's *present in the input*, structure it, and flag what's missing rather than interrogating the user turn by turn. One round of revision is expected; an open-ended interview is not.

## Step 1 — absorb the mess

Take the input exactly as given — transcripts, half-sentences, bullet fragments, contradictory notes, photographed-whiteboard text. Do **not** ask the user to clean it up first; absorbing disorder is the whole point of the skill.

Read it for: the thing being designed, the problem it solves, who it's for, decisions already made, decisions implied but not stated, and open threads. If a source file/PDF is referenced, ingest it with `Read` (PDFs via the `pages` parameter).

## Step 2 — emit the document (this schema, in order)

Use this section order. It is the GDD/design-doc template — the part that makes the output reusable and comparable across specs.

```
# <Name> — Design Doc

## 1. One-liner
   One sentence: what this is, for whom. If the input doesn't support a sharp one-liner, write the best version and tag it [ASSUMED].

## 2. Problem / motivation
   What's broken or missing without this. Why now.

## 3. Goals & non-goals
   - Goals: bulleted, each independently checkable.
   - Non-goals: explicitly out of scope. (Forces the cut the input usually avoids.)

## 4. Design / approach
   The actual proposal. Sub-section per major component or system.
   This is the load-bearing section — give it the most room.

## 5. Key decisions
   Each: the decision, the one-line why, and the alternative not taken.
   Pull these out of the input even when stated only implicitly.

## 6. Open questions
   Phrased as questions. Each tagged [OPEN]. These are the gaps,
   surfaced — not hidden behind confident prose.

## 7. Risks / unknowns
   What could make this wrong or hard. Honest, not pro forma.

## 8. Next steps
   Imperative mood, ≤6 items, ordered by what unblocks the most.
```

Drop a section only if the input has genuinely nothing for it — and when you do, leave the heading with `*(not covered in input)*` so the gap is visible rather than silently erased.

## Step 3 — ground and gap-flag (the discipline)

- **Do not fabricate design decisions.** If the input doesn't settle something, it goes in **Open questions** as `[OPEN]`, never invented into section 4 as if decided.
- **Tag manufactured connective tissue.** Anything you inferred to make the doc read coherently that the input didn't actually say → `[ASSUMED]`. The user must be able to see where you bridged.
- **Preserve disagreement.** If the notes show two people wanting different things and no resolution, the doc records the tension in Key decisions or Open questions — it does not pick a winner.
- **Self reader-test (collapsed from doc-coauthoring Stage 3).** Before delivering, reread section 1 and 4 as someone with zero context. If a term, actor, or system appears undefined, fix it or flag it. Do not spawn a separate pass for this — it's a final check, not a stage.

## Step 4 — one revision pass

After delivering, expect the user to correct or fill gaps. Apply edits **surgically** — change the affected lines, do not regenerate the whole document (preserves their reading position and any edits they made). This mirrors `doc-coauthoring`'s `str_replace` discipline.

## Guardrails

- **Explicit-invoke-only is the contract.** `disable-model-invocation: true` is set on purpose. Never work around it by replicating this template from memory when the skill wasn't invoked — if the user wants a design doc, they invoke the skill.
- **Gaps visible, not filled.** A design doc that hides what it doesn't know is worse than one with honest `[OPEN]` markers. The markers are a feature.
- **Single pass, not an interview.** Structure from what's there; collect gaps into section 6 instead of interrogating the user mid-build. One revision round after, not an open loop.
- **Markdown only.** Output is markdown by design (kit-consistent, diff-able, the Day 17 reuse path). Polished `.docx` is explicitly out of scope — if ever needed it's a separate bundled generator, not this skill.
- **Save location:** default to `artifacts/week<N>/design-doc-<name-slug>.md` in the current project (curriculum convention) unless the user names a path.
