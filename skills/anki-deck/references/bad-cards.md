# Bad card examples (anti-patterns)

Each example shows a card that *looks* reasonable, what's wrong with it, and how to fix it (or drop it). Filter cards matching these shapes during extraction.

---

## Anti-pattern 1 — Multi-fact card

**Source (tip 3):**
> Skills are folders, not files — use `references/`, `scripts/`, `examples/` subdirectories for progressive disclosure.

**❌ Bad card:**
- **Front:** `Describe skill structure in Claude Code.`
- **Back:** `Skills are folders (not files), and they can contain references/, scripts/, and examples/ subdirectories. The structure enables progressive disclosure, which keeps context lean by loading deeper material only when needed.`

**Diagnosis:** Three facts crammed into one card (folder-not-file + subdirectory list + progressive disclosure rationale). Spaced repetition can't grade partial knowledge — if you get one of the three but miss another, the algorithm has no signal. Split into 2–3 atomic cards.

---

## Anti-pattern 2 — Structural trivia

**Source (header line):**
> ## Skills (9)

**❌ Bad card:**
- **Front:** `How many skill tips are in the shanraisshan repo's Skills section?`
- **Back:** `9.`

**Diagnosis:** Tests a structural detail of the source document, not the *content* of the tips. The number 9 is meaningless once divorced from its surrounding context. Reject all "how many bullets in section X" / "what's the title of section Y" questions.

---

## Anti-pattern 3 — List-recall card

**Source (tip 3):**
> Skills are folders, not files — use `references/`, `scripts/`, `examples/` subdirectories.

**❌ Bad card:**
- **Front:** `Name the three subdirectories suggested for skill bundles.`
- **Back:** `references/, scripts/, examples/`

**Diagnosis:** Tests memorization of a list, not the concept. Reader either has the list cached or doesn't. Better card: "What's the *purpose* of subdirectories inside a skill bundle?" — which tests progressive disclosure, the actual idea.

---

## Anti-pattern 4 — Vague stem

**Source (tip 5):**
> Skill description field is a trigger, not a summary.

**❌ Bad card:**
- **Front:** `What about skill descriptions?`
- **Back:** `They're triggers for the model, not user summaries.`

**Diagnosis:** "What about X?" stems give the brain no specific question to answer. The reader can't tell what's being asked. Sharpen the stem until it forces the exact answer.

---

## Anti-pattern 5 — Not self-contained

**Source (tip 8):**
> Include scripts and libraries in skills so Claude composes rather than reconstructs boilerplate.

**❌ Bad card:**
- **Front:** `As mentioned in tip 8, why is this important?`
- **Back:** `So Claude composes rather than reconstructs boilerplate.`

**Diagnosis:** Refers to "tip 8" — if you study this card a month from now, you have no idea what tip 8 said. Self-contained cards survive being mixed into a deck of 1000+. Rephrase to embed the topic in the question stem itself.

---

## Anti-pattern 6 — Yes/no without follow-up

**Source (tip 1):**
> Use `context: fork` to run a skill in an isolated subagent.

**❌ Bad card:**
- **Front:** `Does <code>context: fork</code> isolate the skill?`
- **Back:** `Yes.`

**Diagnosis:** Binary recall is the weakest form. A coin flip would get 50% right. Replace with a "what does X do?" card that forces the actual mechanism into the answer.

---

## Anti-pattern 7 — Source attribution as a card

**Source (tip 1, attribution line):**
> Source: Lydia

**❌ Bad card:**
- **Front:** `Who contributed tip 1 in shanraisshan's repo?`
- **Back:** `Lydia.`

**Diagnosis:** Tests authorship metadata, not concept. Source attribution belongs in the Source field of the card (queryable in Anki's browser), not as a card itself. Drop entirely.

---

## Anti-pattern 8 — Quote-back card

**Source (tip 7):**
> "Don't railroad Claude in skills — give goals and constraints, not prescriptive step-by-step instructions."

**❌ Bad card:**
- **Front:** `Complete the quote: "Don't railroad Claude in skills — give ___"`
- **Back:** `goals and constraints, not prescriptive step-by-step instructions.`

**Diagnosis:** Tests verbatim recall of the source phrasing, not the underlying idea. Cards should test concepts at any phrasing — if you read the same idea expressed differently, you should still recognize it. Replace with a "should you do X or Y" card.

---

## Filtering checklist

Before adding a card, check:
1. **Is exactly one fact under test?** Not two, not a list.
2. **Could I answer this without remembering the source document layout?** If not, drop it.
3. **Is the stem specific enough to force the answer?** Vague stems → drop.
4. **Could a reader 6 months from now understand the card alone?** If it references "tip 3" or "the above" — rewrite.
5. **Is this testing a concept, not a quote or a list?** Quote-backs and list-recalls fail spaced repetition.
6. **Could a coin flip get this right?** If yes — rewrite to force a mechanism into the answer.
7. **Is the source attribution in the right place?** Names go in the `source` field, not the card body.
