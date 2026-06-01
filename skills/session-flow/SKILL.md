---
name: session-flow
description: >-
  Turn a Claude Code session transcript into a vertical, scrollable flowchart
  of what actually happened — the main agent's decision points, every subagent it
  delegated to, and every skill / slash-command it invoked, each with a short
  blurb. Also emits a JSON sidecar of the same flow as evidence for
  project-optimizer. Use this whenever the user wants to SEE how a session
  unfolded, map a session's decisions/handoffs, understand "what did the agents
  do / which subagents ran / how was work delegated," visualize a session or
  conversation as a flow/diagram/map, or types /session-flow. Reach for it even
  if they don't say "flowchart" — any request to trace, map, or explain the
  decision/delegation shape of a past session belongs here. This complements session-report
  (which does cost/token stats); session-flow does control-flow.
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion
---

# Session Flow

Render a past Claude Code session as a **top→bottom flowchart on a grid**: user
prompts and the main agent's decisions descend a gold "main lane" (column 0);
when a step delegates, its subagents splay into columns 1+ as a row-band, then
the spine resumes below; skills and slash-commands appear as green nodes inline.
Every node occupies whole grid cells — busier nodes span more row-units. Each
carries a one-line blurb. The output is a standalone HTML file (scrolls
vertically; columns scroll sideways only if a delegation is very wide) plus a
JSON sidecar.

The bundled parser does the deterministic work (reconstructing order + branching
from the `tool_use`/`tool_result` links); your only judgment step is sharpening
the blurbs.

## How transcripts are laid out

- Main thread: `<projects-dir>/<project>/<sessionId>.jsonl` (one session = one file).
- Subagents: `<project>/<sessionId>/subagents/agent-<id>.jsonl` + a sibling
  `agent-<id>.meta.json` = `{agentType, description, toolUseId}`.
- `<projects-dir>` defaults to `~/.claude/projects`. `<project>` is the cwd with
  path separators replaced by `-` (e.g. `D:\ClaudeCode` → `D--ClaudeCode`).

Full schema in `references/transcript-schema.md` — read it only if the parser
output looks wrong and you need to debug field handling.

## Procedure

### 1. Establish scope (always ask)

Scope is genuinely the user's call, so ask before running — don't assume.
Determine the **project** (default: the current cwd's encoded folder) and then ask
which sessions, using `AskUserQuestion` with two options:

- **Current / latest session** — the most recent transcript in the project dir.
- **Multi-session (user picks)** — list candidates and let them choose a set.

To populate the list, run:

```bash
node ~/.claude/skills/session-flow/scripts/extract-flow.mjs --list --project <encoded-project>
```

This returns JSON: `[{id, mtime_iso, turns, subagents, preview}, …]`, newest
first. Show the user a short readable table (id prefix, time, turns, subagent
count, prompt preview) so they can pick. If they already named a session or said
"this one / the current one," skip the question and use the latest.

### 2. Extract the flow graph

Single session:

```bash
node ~/.claude/skills/session-flow/scripts/extract-flow.mjs --session <id> --project <encoded-project> --out <workdir>/session-flow-<id>.json
```

Multiple: pass `--session <id1>,<id2>,…` (rendered as labeled segments, no
cross-session edges). Omitting `--session` defaults to the latest session.

The JSON shape (also the project-optimizer sidecar) is documented in
`references/flow-schema.md`. Key fields per node: `kind`
(`user|decision|subagent|skill`), `lane` (`main|sub`), `title`, `blurb`,
`toolCounts`, and for subagents `subagent_type`, `prompt_head`, `result_snippet`.

### 3. Sharpen the blurbs (your one judgment step)

The parser writes *draft* blurbs by truncating raw text. Before rendering, read
the JSON and rewrite each node's `blurb` (and `title` where weak) into a tight,
accurate one-liner that says what the step actually *did*. Use the **Edit tool**
to change them in place in the JSON file (not a shell command — avoids quoting
and cross-shell path issues).

Follow these blurb rules:
- **Mechanism, not vibes.** "X does Y by doing Z." Say what the decision was and
  why it led to the next step, not "the agent thought about things."
- **Concrete subjects.** For a subagent, name what it was sent to find and what
  it came back with (use `prompt_head` + `result_snippet`). For a skill, say what
  the skill was used to produce.
- **One line.** ~12–20 words. No trailing summaries, no "successfully."
- Don't invent. If a node's raw material is thin, keep the blurb modest.

Keep `kind`, `lane`, `id`, and all edges untouched — only prose changes.

### 4. Render

Inject the finalized JSON into the template and write the HTML next to the JSON:

```bash
node ~/.claude/skills/session-flow/scripts/render.mjs <workdir>/session-flow-<id>.json <workdir>/session-flow-<id>.html
```

`render.mjs` embeds the JSON at the template's single `__FLOW_DATA__` placeholder
(it finds the template relative to itself, so no template path needed). The data
is inlined, so the HTML is fully self-contained and opens with no server.

### 5. Hand off

Tell the user both paths and that the HTML opens in a browser and **scrolls
vertically** (start at the top, end at the bottom). Mention that subagent cards
are click/Enter-to-expand for the prompt they were given and what they returned.
The `session-flow-<id>.json` sidecar is the artifact a future project-optimizer
pass can ingest as flow evidence.

## Output conventions

- Default `<workdir>`: the current working directory, unless the user names one.
- File names: `session-flow-<sessionId>.html` / `.json` (use the full session id
  so multiple runs don't collide).
- Color legend (baked into the template): **gold** = main thread / decisions,
  **cyan** = subagents, **green** = skills / slash-commands, **neutral** = user
  prompts (red left-border = an interrupt or a subagent that returned nothing).
