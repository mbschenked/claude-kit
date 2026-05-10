---
name: research-brief
description: Synthesize a research conversation, web-search session, or doc-read into a structured brief — question, key findings (with confidence ratings), sources (with tier flags), what wasn't checked, open questions, next actions. Invoke when the user asks for a research brief, says "brief this" / "summarize this research" / "wrap up the search," or types `/research-brief`.
---

# research-brief — convert research into a decision-ready brief

When invoked, the user wants a tight written summary of recent research (web search, doc reads, agent investigation). Convert the conversation into a structured artifact they can save, share, and act on.

## When this fires

- User types `/research-brief`.
- User asks: "brief this," "summarize this research," "wrap up the search," "give me the writeup," or a close paraphrase.
- After a multi-source investigation where the user wants the conclusions captured.

If there isn't enough material in-conversation to brief (e.g., a single Q&A turn), say so plainly and ask what topic or thread they want briefed. Don't invent findings to fill the structure.

## Output structure

Write the brief in this exact section order. Section headers are required — they're how the brief stays scannable and how it's compared across topics over time.

### 1. Question
Restate the question being researched in one sentence. Sharp, not elaborate. If the user's framing was vague, propose the sharpened version explicitly and let them correct before writing the rest.

### 2. Key findings
A numbered list. **Each finding gets a confidence tag** (see rubric). Lead with the claim, then a one-sentence reason or the source it came from.

Format: `1. <claim>. [<confidence>] — <one-sentence why or source pointer>`

Cut findings that don't clear `[inferred]`. Three strong findings beat seven padded ones.

### 3. Sources
A bulleted list. **Each source gets a tier tag** (see rubric). Format: `- [<tier>] <link or citation> — <what it gave you>`. Order: T1 first, then T2, then T3.

### 4. What I didn't check
**This section is required, not optional.** Explicit limits of the brief — questions you didn't ask, sources you didn't pull, angles you skipped, caveats on findings ("only English-language sources," "didn't verify the 2026 numbers against the original methodology"). Default is to find at least 2–3 honest gaps. If scope was genuinely tight and nothing material was left unchecked, write "scope was tight; nothing material left unchecked" — but bias toward naming gaps.

### 5. Open questions
Things the research surfaced but didn't resolve. Phrase as questions, not bullet points. These should be questions the user could chase next.

### 6. Next actions
Concrete, in imperative mood. ≤5 bullets. The first action should be the cheapest step toward resolving the most important open question. If the brief itself is the deliverable and no follow-up is needed, write "none — brief is the deliverable."

## Confidence rubric

Tag every finding with one of:

- **[verified]** — directly supported by a Tier-1 source and consistent across sources you actually checked. Don't tag verified unless you'd defend the claim under pushback.
- **[inferred]** — supported by sources but requires a bridging step (combining sources, applying domain knowledge, reading between lines). The most common honest tag.
- **[speculative]** — your read of the field, weak source coverage, or the user explicitly asked for a take. Acceptable, but call it out.

## Source-tier rubric

Tag every source with one of:

- **[T1]** — official primary: vendor docs, authors' own posts, peer-reviewed papers, primary data, Anthropic docs for Anthropic claims.
- **[T2]** — trusted secondary: established publications, recognized practitioners, conference talks, well-maintained open-source READMEs.
- **[T3]** — community or unverified: Reddit, Medium posts without authors' credentials, screenshots, hearsay. Useful but flag honestly.

If a Tier-1 source contradicts a Tier-3 source, side with Tier 1 and note the contradiction in `What I didn't check` if it warrants follow-up.

## Guardrails

- **No clean dichotomies without verification.** If you're tempted to write "X is for A, Y is for B," check primary sources first — the framing is often wrong on edges. Clean dichotomies are a flag to verify, not to ship.
- **Confidence and tier tags are mandatory, not decorative.** A brief without tags fails the spec.
- **Brevity over completeness.** A one-page brief with three strong findings beats a three-page brief padded with weak ones.
- **The "What I didn't check" section is the distinguishing feature.** Skipping it ships a brief whose limits the reader can't see. Always include it.
- **No filler.** If a section has nothing real to put in it, write a one-sentence honest "none" and move on.
- **Save location:** if the user asks to save the brief, default to `artifacts/week<N>/research-brief-<topic-slug>.md` in the current project (per the curriculum convention) unless the user names a different path.
