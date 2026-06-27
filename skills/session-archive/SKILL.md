---
name: session-archive
description: Bank the current Claude Code session into the ClaudeOptimizer corpus — a metrics-stamped markdown card (exact numbers from the deterministic engine, never hand-typed) + a verbatim raw-transcript copy + a per-project ledger row. Invoke when the user types `/session-archive`, says "archive this session" / "bank this session", or as the final step of `/save`. Skips gracefully (never hard-fails) when ClaudeOptimizer isn't present on this machine.
allowed-tools: Bash, Read, Write, Edit
---

# /session-archive — bank this session into the ClaudeOptimizer corpus

Captures the session as a structured card while it's still in context (nearly free), using the
ClaudeOptimizer engine for **exact** metrics. Follow these steps in order. Keep it tight.

## 1. Resolve the ClaudeOptimizer root — or skip

Find the corpus repo, in this order:

1. `$env:CLAUDE_OPTIMIZER_ROOT` / `$CLAUDE_OPTIMIZER_ROOT` if set.
2. OS default: **Windows** `D:\ClaudeCode\ClaudeOptimizer` · **macOS/Linux** `~/ClaudeCode/ClaudeOptimizer`.

Verify the path exists and contains `scripts/build-card.mjs`. **If it does not, STOP and report one line:**
`session-archive skipped — ClaudeOptimizer not found at <path> (set CLAUDE_OPTIMIZER_ROOT to enable).`
Never create the repo, never error out — this step is best-effort by design.

Also confirm `node` is available (`node --version`, needs ≥18). If absent, skip with a one-line notice.

## 2. Locate the current session transcript

The live transcript is the most-recently-modified top-level `*.jsonl` in this project's transcript
folder:

- **Windows:** `C:\Users\<user>\.claude\projects\<encoded-cwd>\`
- **macOS/Linux:** `~/.claude/projects/<encoded-cwd>/`

`<encoded-cwd>` is the absolute cwd with drive-colon and path separators replaced by `-`
(e.g. `D:\ClaudeCode\TOG-Remake` → `D--ClaudeCode-TOG-Remake`; `/Users/x/ClaudeCode/TOG-Remake` →
`-Users-x-ClaudeCode-TOG-Remake`). Pick the newest `*.jsonl` directly in that folder (ignore the
`subagents/` subdir — the engine discovers those itself). If you can't identify it, ask the user to
confirm the path rather than guessing wrong.

## 3. Classify + name the session

Decide, from the conversation you're in:

- **`--name`** — a short kebab-case topic, e.g. `orchestrate-port-and-save-update`.
- **`--project`** — the **basename of the current working directory** (authoritative; the engine's own
  guess is lossy for dashed names like `TOG-Remake`). Always pass this.
- **`--phase`** — `research | plan | execute | review | ship` (the session's dominant phase).
- **`--outcome`** — `success | partial | abandoned`.
- **`--grade`** — 1–5 best-practices grade *if known* (e.g. when `/save`'s grading ran); otherwise omit.
- **`--date`** — today, `YYYY-MM-DD` (omit to let the engine default to today).

## 4. Write the narrative, then build the card

Write the **six-section narrative** to a temp file in the OS temp dir — `$env:TEMP\session-archive-narrative.md`
(Windows) / `/tmp/session-archive-narrative.md` (macOS/Linux), never the project cwd. Be specific and
short — this is the durable lesson, not a transcript:

1. **Intent** — why the session ran.
2. **Key Decisions** — design forks resolved, and how.
3. **What Worked** — techniques / orchestrations that paid off.
4. **What Was Wasteful** — tokens or time spent without clear benefit.
5. **Corrections Issued** — feedback loops the user closed.
6. **Outcome** — success / partial / abandoned, with the concrete end-state.

Then invoke the engine (it runs `extract-metrics.mjs` for exact numbers, copies the raw transcript,
and writes the card). **Never hand-type metrics.**

PowerShell (Windows):
```powershell
node "$Root\scripts\build-card.mjs" `
  --jsonl "<transcript.jsonl>" --repo "$Root" `
  --name "<kebab-name>" --narrative "<narrative.md>" --project "<cwd-basename>" `
  --phase "<phase>" --outcome "<outcome>"   # add --grade N if known
```

bash (macOS/Linux):
```bash
node "$ROOT/scripts/build-card.mjs" \
  --jsonl "<transcript.jsonl>" --repo "$ROOT" \
  --name "<kebab-name>" --narrative "<narrative.md>" --project "<cwd-basename>" \
  --phase "<phase>" --outcome "<outcome>"   # add --grade N if known
```

**If the command exits non-zero**, print its error line and skip straight to the Report step (step 6)
with a "skipped — <reason>" — do not retry or abort. On success it prints the written card path on
stdout; use that exact path in the report (don't reconstruct it).

## 5. Update the project ledger

Ensure `<root>/sessions/<project>/LEDGER.md` exists. If missing, create it with the header:

```markdown
# Optimization Ledger — <project>

| date | optimization | source session | applied? | rating | proxy result | status |
|------|--------------|----------------|----------|--------|--------------|--------|
```

Add a row **only if this session produced an applied optimization** (a real change to config,
tooling, workflow, or code-process worth tracking over time). Use the card's `<name>-<date>` as the
source session; set `rating`/`proxy result` to `(await)` and `status` to `applied`. A session that
was pure investigation with no applied change needs no ledger row.

## 6. Report

One block, ≤8 lines:

```
Archived to ClaudeOptimizer:
- card: sessions/<project>/<name>-<date>.md
- raw:  sessions/<project>/raw/<name>-<date>.jsonl
- metrics: <grand_total> tok · <cache%> cache · ~$<cost> · peak ctx <pct>%
- ledger: <row added | unchanged>
```

## Guardrails

- **Never hard-fail `/save`.** If anything here errors, report the error in one line and let the
  caller continue — archiving is additive, not load-bearing.
- Metrics come **only** from the engine. If you're tempted to type a number, you've gone wrong.
- Don't commit the corpus from here — ClaudeOptimizer is its own repo; the user manages its commits.
- Don't archive a session with secrets in the transcript without flagging it; the raw `.jsonl` is
  copied verbatim. Note it in the report if the transcript contains credentials.
