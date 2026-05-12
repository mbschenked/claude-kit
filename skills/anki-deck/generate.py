#!/usr/bin/env python3
"""anki-deck — build a Destiny 2 themed .apkg from a JSON card list.

Companion to ~/.claude/skills/anki-deck/SKILL.md. Claude extracts atomic cards
from a source and writes them to a JSON file matching the schema below; this
script consumes that JSON and produces a styled .apkg ready to import into Anki.

JSON schema (list of card objects):
    [
      {
        "front": "<html>...",     # required; HTML allowed; angle-brackets pre-escaped
        "back":  "<html>...",     # required; same rules
        "tags":  ["claude-code", "skills"],   # optional; hyphenated, no spaces
        "source": "_source-shan-skills.md#tip-3"   # optional; per-card override
      },
      ...
    ]

CLI:
    python3 generate.py --input cards.json --output deck.apkg --deck-name "Name"
                        [--source-url "default-source-string"]
                        [--regenerate-ids]   # rare; new deck/model identities
"""

import argparse
import json
import re
import sys
import zlib
from pathlib import Path

import genanki


CODE_BLOCK_RE = re.compile(r"(<code>)(.*?)(</code>)", re.DOTALL | re.IGNORECASE)


def escape_code_blocks(html: str) -> str:
    """Escape <, >, & inside <code>...</code> tags so genanki doesn't drop them.

    Order matters: & must escape first, otherwise `<` → `&lt;` would then have its
    `&` re-escaped to `&amp;`, producing `&amp;lt;`. Outside <code>, raw HTML passes
    through so <em>/<strong>/<br>/<ul>/<li>/<kbd> all work as intended.
    """
    def _escape(match: "re.Match[str]") -> str:
        opening, inner, closing = match.group(1), match.group(2), match.group(3)
        escaped = (
            inner.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
        )
        return opening + escaped + closing

    return CODE_BLOCK_RE.sub(_escape, html)


MODEL_ID = 1759834521
MODEL_NAME = "Destiny2 Basic"


CARD_CSS = """
.card {
  background: #0E1116;
  color: #E8E8E5;
  font-family: "SF Pro Display", "Helvetica Neue", "Inter", system-ui, -apple-system, "Segoe UI", sans-serif;
  font-size: 22px;
  line-height: 1.45;
  padding: 32px 28px;
  text-align: left;
  -webkit-font-smoothing: antialiased;
}

.card-frame {
  position: relative;
  padding: 28px 24px;
  border: 1px solid rgba(232, 232, 229, 0.08);
  margin-bottom: 16px;
}

.card-frame .corner {
  position: absolute;
  width: 16px;
  height: 16px;
  pointer-events: none;
}
.card-frame .corner.tl { top: -1px; left: -1px; }
.card-frame .corner.br { bottom: -1px; right: -1px; }

.front .corner { color: #4FC3F7; }
.back  .corner { color: #E5A55A; }

.label {
  font-size: 11px;
  letter-spacing: 0.28em;
  text-transform: uppercase;
  margin-bottom: 14px;
  opacity: 0.7;
}
.front .label { color: #4FC3F7; }
.back  .label { color: #E5A55A; }

.front-text {
  font-weight: 700;
  font-size: 26px;
  line-height: 1.25;
  letter-spacing: -0.005em;
}

.back-text {
  font-weight: 400;
  font-size: 21px;
}

.back-text code,
.front-text code {
  font-family: "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace;
  font-size: 0.9em;
  background: rgba(79, 195, 247, 0.10);
  padding: 1px 6px;
  border-radius: 2px;
  color: #E8E8E5;
}

.divider {
  border: 0;
  border-top: 1px solid rgba(229, 165, 90, 0.22);
  margin: 22px 0;
}

.tagline {
  margin-top: 22px;
  font-family: "SF Mono", "JetBrains Mono", Menlo, monospace;
  font-size: 11px;
  letter-spacing: 0.12em;
  color: rgba(232, 232, 229, 0.35);
}

.nightMode.card { background: #0E1116; color: #E8E8E5; }
"""


CORNER_TL_SVG = (
    '<svg class="corner tl" viewBox="0 0 40 40" preserveAspectRatio="none" '
    'aria-hidden="true"><polygon points="0,0 40,0 0,40" fill="currentColor"/></svg>'
)
CORNER_BR_SVG = (
    '<svg class="corner br" viewBox="0 0 40 40" preserveAspectRatio="none" '
    'aria-hidden="true"><polygon points="40,40 40,0 0,40" fill="currentColor"/></svg>'
)


FRONT_TMPL = f"""<div class="card-frame front">
  {CORNER_TL_SVG}
  {CORNER_BR_SVG}
  <div class="label">QUERY</div>
  <div class="front-text">{{{{Front}}}}</div>
</div>"""


BACK_TMPL = f"""{{{{FrontSide}}}}
<hr class="divider">
<div class="card-frame back">
  {CORNER_TL_SVG}
  {CORNER_BR_SVG}
  <div class="label">RESPONSE</div>
  <div class="back-text">{{{{Back}}}}</div>
  <div class="tagline">{{{{Tags_display}}}}</div>
</div>"""


def build_model() -> genanki.Model:
    return genanki.Model(
        MODEL_ID,
        MODEL_NAME,
        fields=[
            {"name": "Front"},
            {"name": "Back"},
            {"name": "Tags_display"},
            {"name": "Source"},
        ],
        templates=[
            {
                "name": "Card 1",
                "qfmt": FRONT_TMPL,
                "afmt": BACK_TMPL,
            }
        ],
        css=CARD_CSS,
    )


def deck_id_from_name(deck_name: str) -> int:
    """Deterministic 31-bit deck ID from name — same name → same deck → safe re-import."""
    return zlib.crc32(deck_name.encode("utf-8")) & 0x7FFFFFFF


def validate_card(card: dict, idx: int) -> None:
    if "front" not in card or "back" not in card:
        raise ValueError(f"card[{idx}] missing 'front' or 'back'")
    tags = card.get("tags", [])
    if not isinstance(tags, list):
        raise ValueError(f"card[{idx}] tags must be a list")
    for t in tags:
        if not isinstance(t, str) or " " in t:
            raise ValueError(
                f"card[{idx}] tag {t!r} invalid — tags must be hyphenated strings (no spaces)"
            )


def build_note(card: dict, model: genanki.Model, deck_name: str, default_source: str) -> genanki.Note:
    front = escape_code_blocks(card["front"])
    back = escape_code_blocks(card["back"])
    tags = card.get("tags", [])
    source = card.get("source") or default_source or ""

    tags_display = " · ".join(tags) if tags else ""

    # GUID derived from the *original* front so existing review history survives
    # the escaping change — re-importing the same source produces matching GUIDs.
    return genanki.Note(
        model=model,
        fields=[front, back, tags_display, source],
        tags=tags,
        guid=genanki.guid_for(card["front"] + "::" + deck_name),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a Destiny 2 themed Anki .apkg from JSON cards.")
    parser.add_argument("--input", required=True, help="Path to cards JSON")
    parser.add_argument("--output", required=True, help="Path to write .apkg")
    parser.add_argument("--deck-name", required=True, help="Anki deck name (also the import title)")
    parser.add_argument("--source-url", default="", help="Default source string for cards lacking one")
    parser.add_argument(
        "--regenerate-ids",
        action="store_true",
        help="Use a fresh deck ID. Default is deterministic from deck name (safe for re-import).",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.is_file():
        print(f"ERROR: input not found: {input_path}", file=sys.stderr)
        return 2

    with input_path.open() as f:
        cards = json.load(f)

    if not isinstance(cards, list) or not cards:
        print("ERROR: input JSON must be a non-empty list of cards", file=sys.stderr)
        return 2

    for i, card in enumerate(cards):
        validate_card(card, i)

    model = build_model()

    if args.regenerate_ids:
        import random
        deck_id = random.randint(1 << 30, (1 << 31) - 1)
    else:
        deck_id = deck_id_from_name(args.deck_name)

    deck = genanki.Deck(deck_id, args.deck_name)

    for card in cards:
        deck.add_note(build_note(card, model, args.deck_name, args.source_url))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    genanki.Package(deck).write_to_file(str(output_path))

    size_kb = output_path.stat().st_size / 1024
    print(
        f"wrote {len(cards)} cards → {output_path}  "
        f"({size_kb:.1f} KB, deck_id={deck_id}, model_id={MODEL_ID})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
