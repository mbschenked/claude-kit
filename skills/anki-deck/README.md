# anki-deck

Convert a markdown file, plain text, or URL into a Destiny 2-themed Anki flashcard deck (`.apkg`). Claude extracts atomic cards from the source using the rules in `SKILL.md` and the worked examples in `references/`; `generate.py` packages them into a styled `.apkg` ready to import.

## What it does

- Reads a source (markdown, plain text, URL, or pasted content)
- Extracts atomic flashcards (one fact per card) targeting non-obvious content: rules, gotchas, definitions, decision criteria, anti-patterns
- Filters structural trivia ("how many items in section 2") and weak-stem cards
- Outputs a single `.apkg` file with a Destiny 2-themed card template — dark charcoal background, cream grotesk type, cyan/amber accents, angular SVG corner cuts

## How to use it

**Setup (one-time):**
```bash
pip install genanki==0.13.1
```

**Invoke in Claude Code:**
- `/anki-deck path/to/source.md`
- Or say: "make an anki deck from `path/to/source.md`"
- Or pass a URL: "build flashcards from https://example.com/article"

Claude will read the source, extract cards, write a JSON intermediate, run `generate.py`, and report the output path + card count.

**Direct CLI use** (skipping Claude's extraction):
```bash
python3 ~/.claude/skills/anki-deck/generate.py \
  --input cards.json \
  --output deck.apkg \
  --deck-name "My Deck Name"
```

Then import the `.apkg` in Anki: **File → Import → select file**.

## Card JSON schema

```json
[
  {
    "front": "<html>...</html>",
    "back":  "<html>...</html>",
    "tags":  ["hyphenated-strings", "no-spaces"],
    "source": "optional-per-card-override"
  }
]
```

- HTML allowed in `front` / `back`. Pre-escape `<`, `>`, `&` inside `<code>` blocks.
- Tags must be hyphenated (Anki splits on whitespace).
- `source` is optional — falls back to `--source-url` if omitted.

## What it can't do

- **Cloze deletion cards.** v1 ships Basic notes only (front + back). For cloze, edit `generate.py` to add a second `genanki.Model`.
- **Image attachments.** Diagrams in source documents are skipped silently. v2 hook.
- **MathJax escape pre-processing.** Sources with raw `\(...\)` or `\[...\]` need manual escaping (`\\` doubling). Rare in code-skills content.
- **AnkiDroid <2.16 SVG fallback.** Older AnkiDroid builds may strip inline SVG corners. Acceptable for the Mac/iPhone primary target.
- **Custom-font embedding.** Uses system font stack only (SF Pro → Helvetica → Inter → Roboto). Embedding adds ~600 KB per font and AnkiWeb ignores embedded fonts anyway.
- **Editing a card's front and re-importing.** GUID is derived from `front + deck_name`, so a front-edit creates a new card and orphans the old one (with its review history). Back edits are safe.

## Files

- `SKILL.md` — main procedure Claude follows on invocation
- `generate.py` — `genanki`-based `.apkg` builder; ~150 lines; argparse CLI
- `references/destiny-theme.md` — color palette, type rationale, platform notes
- `references/good-cards.md` — 7 worked examples with rationale
- `references/bad-cards.md` — 8 anti-patterns + filtering checklist

## Determinism

- `MODEL_ID` is hardcoded (re-running the generator does not duplicate cards on re-import)
- `DECK_ID` is derived via `zlib.crc32(deck_name)` (same deck name → same Anki deck)
- Note GUID is `genanki.guid_for(front + "::" + deck_name)` (idempotent re-import; same front in different decks doesn't collide)
- Use `--regenerate-ids` to force a fresh deck identity

## Provenance

Built by Max Schenk + Claude as Day 5 of the Claude Code Capability Tour (2026-05-12). First skill in the kit to bundle a Python executable alongside `SKILL.md`. Destiny 2 visual language references: Ryan Klaverweide, David Candland, Game UI Database.
