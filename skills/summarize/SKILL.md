---
name: summarize
description: Targeted summarization of a document, PDF, or transcript into one of three named modes — executive (decision-maker's read), key-points (scannable claims), or decision-log (what was decided + why + open).
when_to_use: Invoke when the user asks to "summarize X," "give me the gist of X," "TL;DR this," "what does this doc say," or types `/summarize`. Not for naive whole-text compression, not for research-session synthesis (that's research-brief), not for draft critique (that's draft-critique).
allowed-tools: Read
---

# summarize — targeted, grounded document summarization

When invoked, the user has a document, PDF, or transcript and wants it compressed *for a purpose*. The job is not "make this shorter" — it is "tell me what I need from this, in the shape that matches why I'm asking, without inventing anything."

## Scope boundary

This skill compresses a *supplied* source for a purpose. It does **not** synthesize a multi-source research session (that is `research-brief`) or critique a draft (that is `draft-critique`). If the ask is "what's wrong with this" or "wrap up the research," hand off — don't summarize. (Trigger phrases live in `when_to_use`; not duplicated here.)

## Step 1 — ingest the source

- **PDF / file on disk:** use the `Read` tool. For PDFs use the `pages` parameter; for anything over ~20 pages, read in page ranges and summarize incrementally rather than forcing the whole document into one pass.
- **Pasted text / transcript:** use it as given.
- **Large document:** state up front how you're chunking it ("summarizing in 3 page-range passes, then consolidating") so the user can see the seams. Never silently drop the tail of a long document.

If the source is missing or unreadable, say so and ask for it. Do not summarize from the filename or your prior knowledge of the topic.

## Step 2 — pick the mode

If the user named a mode, use it. If not, infer from *why they're asking* and state the choice in one line before the summary ("Using **decision-log** mode — this is a meeting transcript and you asked what was agreed."). The user can override.

### Mode: `executive`
A decision-maker's read. 3–6 sentences or ≤6 bullets. Leads with the conclusion / bottom line, then only the facts that change a decision. No methodology, no preamble. Answers: *"If I read nothing else, what do I do or know?"*

### Mode: `key-points`
A scannable extraction. Numbered list, each point one claim, ordered by importance not document order. Each point is a standalone assertion the reader could quote. No narrative connective tissue. Answers: *"What are the load-bearing claims in here?"*

### Mode: `decision-log`
For meetings, threads, design discussions. Three labeled sections:
- **Decided** — what was concluded, each with the one-line reason it was chosen.
- **Open** — unresolved questions or deferred items, phrased as questions.
- **Action** — concrete next steps in imperative mood, with owner if the source names one.
Answers: *"What changed, what's still up in the air, who does what?"*

## Step 3 — ground every claim

This is the discipline that separates this skill from naive summarization:

- **Every claim must trace to the source.** If you can't point to where in the document it came from, it doesn't go in the summary.
- **Mark inference explicitly.** If you connected two parts of the document to draw a conclusion the document doesn't state outright, tag it `[inferred]`. If you're filling a gap with general knowledge, tag it `[external]` — and prefer to just flag the gap instead.
- **Never fabricate specifics.** No invented numbers, dates, names, or quotes. If the document is vague on something the user clearly wants, say "the document does not specify X" rather than producing a plausible value.
- **Preserve load-bearing hedges.** If the source says "preliminary," "we think," "in some cases," do not launder it into a flat assertion. The hedge is part of the claim.
- **Surface contradictions.** If the document contradicts itself, say so — don't silently pick one side.

## Guardrails

- **Mode is mandatory and stated.** A summary that doesn't declare its mode fails the spec — the mode is the contract for what shape the output takes.
- **Compression is not distortion.** Dropping detail is the job; changing meaning, strength, or attribution is a failure.
- **No preamble.** Don't open with "This document discusses…". Start with the summary content itself.
- **Length serves the mode, not a word count.** `executive` is short by design; `key-points` is as long as there are real load-bearing claims and no longer.
- **Building an API app instead of using this in Claude Code?** See `references/api-app-path.md` — the document-block + Files-API + citations mechanism is a different (and more powerful, citation-anchored) path than the in-conversation `Read` approach this skill uses.
- **Save location:** if the user asks to save the summary, default to `artifacts/week<N>/summary-<source-slug>.md` in the current project (per the curriculum convention) unless the user names a different path.
