---
name: anki-deck
description: Convert a text source (markdown, plain text, or URL) into an Anki flashcard deck (.apkg). Produces atomic Q/A cards — one fact each — targeting non-obvious content like rules, gotchas, definitions, and decision criteria. Not for cloze deletion, image-heavy sources, or one-shot reference cards.
when_to_use: User asks to "make an anki deck from X," "convert X to flashcards," "build cards from X," or types `/anki-deck`. Also after a user reads or pastes a source and signals they want it converted to spaced-repetition cards.
---

# anki-deck — convert a source into styled Anki flashcards

When invoked, the user wants atomic flashcards extracted from a source and packaged as a styled `.apkg` they can import directly into Anki. Card extraction is your judgment job; `.apkg` assembly is `generate.py`'s job.

If the source is empty or trivially short (a single sentence), say so plainly and ask for more material. Don't invent cards to fill the count.

## One-time setup

The user must have `genanki==0.13.1` installed in their active Python environment:

```bash
pip install genanki==0.13.1
python3 -c "import genanki; print(genanki.__version__)"
```

If `import genanki` fails when you run `generate.py`, surface the `pip install` line and stop — do not silently swallow the error.

## Procedure

1. **Read the source.** Use the Read tool. If it's a URL, fetch it. If it's pasted text in the conversation, use that directly.
2. **Extract atomic cards.** Follow the rules below and the worked examples in `references/good-cards.md`. Filter against the anti-patterns in `references/bad-cards.md`. For a dense source (numbered tips, rules lists, glossaries), expect 1–2 cards per logical unit. For prose, expect 1 card per ~150–300 words of substantive content. Wrap inline code samples in `<code>...</code>` — `generate.py` escapes `<`, `>`, `&` inside those tags automatically; do not pre-escape.
3. **Write the JSON.** Schema below. Save to a temp file (e.g. `/tmp/anki-cards-<topic>.json`).
4. **Invoke generate.py.** Run via Bash:
   ```bash
   python3 ~/.claude/skills/anki-deck/generate.py \
     --input /tmp/anki-cards-<topic>.json \
     --output <path-to-output.apkg> \
     --deck-name "<Human-readable deck name>" \
     --source-url "<optional default source for cards lacking one>"
   ```
5. **Confirm the output.** Report the absolute path to the `.apkg`, the card count, and the file size. Tell the user: "Import via Anki → File → Import → select this file."

## Card extraction rules

These are the goals — apply judgment. The references hold concrete examples.

1. **One fact per card.** No compound cards, no "list three things." Multi-fact cards break spaced repetition because the algorithm can't grade partial knowledge.
2. **Target non-obvious content.** Rules, gotchas, definitions, decision criteria, anti-patterns, mechanisms. Skip restatements of what's already obvious to anyone who'd read the source.
3. **Filter structural trivia.** "What's the title of section 2," "how many bullets in tip 3" — drop. They test document layout, not concepts.
4. **Self-contained.** A card studied six months from now, mixed into a 1000-card deck, must still make sense. Never reference "tip 3," "the above," "as mentioned." Rephrase to embed the topic in the stem.
5. **Stem forces the answer.** "Why" / "What" / "Should I X or Y." Never a yes/no without a follow-up half. Reject any stem starting with "what about" — too vague.
6. **Test concepts, not quotes.** Cards should survive paraphrased recall. Verbatim quote-back cards fail.
7. **Source attribution → `source` field, not card body.** Author names, tip numbers, URL fragments belong in the metadata, not in the front or back.

For each candidate card, mentally run the **filtering checklist** at the bottom of `references/bad-cards.md`. If a card fails any item, fix it or drop it.

## Output contract

The JSON is a non-empty list of card objects. Schema:

```json
[
  {
    "front": "string — HTML allowed; pre-escape angle brackets in code",
    "back":  "string — HTML allowed; same rules",
    "tags":  ["hyphenated-strings", "no-spaces", "lowercase"],
    "source": "optional per-card override of --source-url"
  }
]
```

- `front` and `back` are **required**.
- HTML elements safe to use: `<code>`, `<em>`, `<strong>`, `<br>`, `<ul>`/`<li>`, `<kbd>`. Avoid `<div>` and `<p>` — Anki renders fields inside the card template's wrappers, so extra block elements stack awkwardly.
- `tags` is optional but recommended. **Hyphenate**: `claude-code`, not `claude code`. Anki splits tags on whitespace, so a space-containing tag silently becomes two tags.
- `source` is optional per-card. If omitted, the card inherits `--source-url`.

## Gotchas

These are the failure modes that have actually bitten this skill. Read before every run.

1. **HTML escape is automatic inside `<code>` blocks.** `generate.py` escapes `<`, `>`, `&` inside `<code>...</code>` tags at note-build time. Do not pre-escape — you'll double-escape. Outside `<code>` blocks, raw HTML passes through, so `<em>`/`<strong>`/`<br>` work as intended.
2. **`Tags_display` is a rendered field, not Anki's real tags.** The card template shows `{{Tags_display}}` (the joined string). Anki's actual filterable tags come from `genanki.Note(tags=...)`. `generate.py` handles both — your job is just to provide a clean hyphenated list in the `tags` array.
3. **Editing a card's front after import creates a new card** (the GUID is derived from `front + deck_name`). Back edits are safe — same GUID, Anki updates in place. If you need to change a question stem, expect the old card to become orphaned with its review history. Re-import after the edit; you can delete the orphan in Anki's browser.
4. **Tags with spaces silently become two tags.** This is the most common bug. `generate.py` asserts that all tags are space-free and will fail loudly — fix the tag list, don't bypass the assertion.

## Author

Max Schenk, ClaudeCurriculum Day 5 — content-automation skill (2026-05-12). Companion to `generate.py` in the same bundle. References live in `references/`.
