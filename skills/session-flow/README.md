# session-flow

Turn a Claude Code session transcript into a **vertical, scrollable HTML flowchart** of
what actually happened — the main agent's decision points, every subagent it delegated to,
and every skill / slash-command it invoked, each with a one-line blurb. Also emits a JSON
sidecar of the same flow (intended as future evidence for `project-optimizer`).

It complements **session-report**: that plugin reports cost/token *stats*; session-flow
reconstructs *control flow* — the order, the hand-offs, and the branching that session-report
discards.

## What it produces

A standalone HTML file (opens with no server) laid out on a grid:

- The main lane is a gold spine running **top→bottom** in column 0 (user prompts + decisions).
- When a step delegates, its parallel subagents splay into columns 1+ as a row-band, then the
  spine resumes below. Skills / slash-commands appear inline.
- Every node occupies whole grid row-units (busy nodes span more) — measured at render time so
  nothing overlaps. Connectors are orthogonal (straight lines + right angles only).
- Destiny 2-inspired palette: **gold** = main thread/decisions, **Arc cyan** = subagents,
  **Strand green** = skills, red = interrupts. Subagent cards are click/Enter-to-expand.

Plus `session-flow-<id>.json` — the flow graph (`nodes`, `edges`, `summary`).

## Usage

The skill triggers on requests to map / trace / visualize how a past session unfolded, or
`/session-flow`. Manually:

```bash
# list sessions in a project (newest first)
node ~/.claude/skills/session-flow/scripts/extract-flow.mjs --list --project D--ClaudeCode

# build one session's flow graph
node ~/.claude/skills/session-flow/scripts/extract-flow.mjs \
  --session <sessionId> --project <encoded-project> --out flow.json

# render the standalone HTML
node ~/.claude/skills/session-flow/scripts/render.mjs flow.json flow.html
```

`--project` is the cwd with path separators replaced by `-` (e.g. `D:\ClaudeCode` →
`D--ClaudeCode`); it defaults to the current cwd. Pass a comma-separated list to `--session`
to render several sessions as labeled stacked strips.

## Layout

```
session-flow/
├── SKILL.md                      # triggers + orchestration (scope → extract → sharpen blurbs → render)
├── scripts/
│   ├── extract-flow.mjs          # transcript JSONL → ordered, branching flow-graph JSON
│   └── render.mjs                # inject JSON into the template → standalone HTML
├── assets/template.html          # vertical-grid renderer (Destiny 2 palette, orthogonal edges)
└── references/
    ├── transcript-schema.md      # the transcript JSONL fields session-flow reads
    └── flow-schema.md            # the emitted flow-graph JSON shape
```

Requires Node.js. Reuses transcript-parsing conventions proven in the `session-report` plugin.
