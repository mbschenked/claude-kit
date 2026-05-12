# Destiny 2 — card theme reference

Visual language for the `anki-deck` skill's card template. This file documents the *why*; the actual HTML+CSS lives inside `generate.py`'s `CARD_CSS`, `FRONT_TMPL`, and `BACK_TMPL` constants. Update both when the design changes.

## Source language

Destiny 2's UI (designed by Ryan Klaverweide, David Candland and team at Bungie) is built on:

- Deep charcoal backgrounds with subtle warm bias (not pure black, not blue-cool)
- High-contrast cream/off-white primary text
- Element-coded accent palette (Arc cyan, Solar amber, Void purple, Stasis ice-blue, Strand green) used sparingly as semantic cues
- Wide-tracked small uppercase labels for category framing
- Angular geometric framing — diagonal corner cuts, hexagonal HUD elements, thin 1px decorative lines
- Generous negative space; the UI never crowds
- Grotesk sans-serif typography (Neue Haas Grotesk in-game)
- No glow, no animation, no decorative imagery on functional surfaces

## Color palette (locked)

| Token | Hex | Use |
|---|---|---|
| `--bg` | `#0E1116` | Card background. Warm-bias near-black. |
| `--text` | `#E8E8E5` | Primary text. Warm cream off-white, not pure white. |
| `--text-dim` | `rgba(232, 232, 229, 0.55)` | Labels, dim metadata. |
| `--text-faint` | `rgba(232, 232, 229, 0.35)` | Tag row at bottom. |
| `--rule` | `rgba(232, 232, 229, 0.08)` | Frame border. Barely visible — it frames without competing. |
| `--accent-front` | `#4FC3F7` | Cyan. Front (question) label + corner triangles + code-tint background. Arc-element nod. |
| `--accent-back` | `#E5A55A` | Amber/gold. Back (answer) label + corner triangles + divider. Solar / Exotic-rarity nod. |

## Type stack (no embedded fonts)

```
"SF Pro Display", "Helvetica Neue", "Inter", system-ui, -apple-system, "Segoe UI", sans-serif
```

Rationale: Embedded fonts bloat `.apkg` files (Inter Regular+Bold ≈ 600 KB compressed) and AnkiWeb's preview doesn't honor embedded fonts anyway. The stack resolves to SF Pro on Mac/iPhone (Max's primary devices), Helvetica on older macOS, Inter on systems that have it, Roboto on AnkiDroid (acceptable degradation — still a grotesk).

Monospace inline-code stack:
```
"SF Mono", "JetBrains Mono", Menlo, Consolas, monospace
```

## Decorative approach

**Use inline SVG triangles for corner cuts, not `clip-path: polygon()`.**

`clip-path` is supported on Anki desktop (Qt WebEngine / Chromium) and modern AnkiDroid (Android System WebView 70+), but older AnkiDroid (System WebView pre-60, Android 7 and earlier) silently no-ops it — the corner cuts disappear without any error. Inline SVG renders identically on every WebView Anki has ever shipped.

The corners are 16x16 px right triangles, positioned `top: -1px / left: -1px` and `bottom: -1px / right: -1px` so they bleed slightly past the 1px frame border. Front uses `--accent-front`, back uses `--accent-back`. The SVG's `fill="currentColor"` lets CSS swap the color cleanly.

## Layout structure

```
.card                                 (root — bg + type defaults)
  .card-frame.front                   (1px rule border + 28px padding)
    svg.corner.tl (cyan triangle)
    svg.corner.br (cyan triangle)
    .label "QUERY"                    (11px, 0.28em letter-spacing, dim cyan)
    .front-text {{Front}}             (26px bold grotesk)

  (back template repeats front, then:)
  hr.divider                          (1px amber line, 0.18 alpha)
  .card-frame.back
    svg.corner.tl (amber)
    svg.corner.br (amber)
    .label "RESPONSE"                 (11px, 0.28em letter-spacing, dim amber)
    .back-text {{Back}}               (21px regular grotesk)
    .tagline {{Tags_display}}         (11px mono, dim cream, 0.12em letter-spacing)
```

## Sizing

- Card root font-size: `22px` (Anki's default ~20–24; this lands clean on phone and laptop)
- Front question: `26px / 700` weight
- Back answer: `21px / 400` weight
- Labels and tagline: `11px` uppercase, wide letter-spacing
- Line-height: `1.45` on body, tighter (`1.25`) on the bold front text
- Padding: 32px vertical / 28px horizontal on `.card`; 28px / 24px on inner frame

## Anki night mode

Anki applies `nightMode` class to `.card` when night theme is active. Since this card is dark-mode-first, the night-mode rule just reasserts the same background and text colors — no inversion needed. Important: do *not* leave `.card` background unstyled, or Anki's default white background will flash for a frame on slow renders.

## Do not add (v1)

- Glow effects (`text-shadow`, `box-shadow` with blur) — Destiny 2 uses them sparingly and they read as kitsch on flashcards
- Animations / transitions — flashcards are reviewed at speed; movement is noise
- Background images, hex-grid SVG patterns — out of scope, would bloat the deck
- Element-tier color (purple/green/ice-blue) — front/back accents are enough for v1
- Custom fonts as `.apkg` media — see "Type stack" rationale
- Card-back "Studied X times" metadata — Anki provides this via its own UI

## Platform notes

| Surface | Type renders as | Corner SVG | Verdict |
|---|---|---|---|
| Anki desktop (Mac) | SF Pro | ✅ | Primary target |
| AnkiMobile (iPhone) | SF Pro | ✅ | Primary target |
| AnkiDroid 2.16+ | Roboto | ✅ | Acceptable |
| AnkiDroid <2.16 | Roboto | ⚠️ may strip inline SVG | Out of scope (Max is on Mac + iPhone) |
| AnkiWeb preview | Helvetica/Arial | ⚠️ may ignore custom CSS | Out of scope (sync target only) |

## Provenance

Custom design by Max Schenk + Claude (Day 5 of Capability Tour, 2026-05-12). Visual language references:
- Ryan Klaverweide — https://www.behance.net/gallery/60073341/Destiny-2-UI-Visual-Design
- David Candland — http://www.cand.land/destiny
- Game UI Database — https://www.gameuidatabase.com/gameData.php?id=175
