---
name: doc-sync
description: Reports which of a project's docs (CLAUDE.md, README, CHANGELOG, docs/, API refs, examples) went stale after a coding session — reads the git diff + session transcript, returns a read-only prioritized brief with paste-ready fix diffs. Proposes, never edits.
when_to_use: Invoke when the user asks "what docs are stale after this session," "did my changes break any docs," "check which docs need updating after my changes," or types `/doc-sync`. Produces a read-only staleness report only — not for applying doc edits, writing docs from scratch (technical-writer), or auditing doc size/structure (project-optimizer).
disable-model-invocation: false
context: fork
agent: doc-sync-analyzer
allowed-tools: Read, Glob, Grep, Bash
---

# doc-sync — which docs did this session make stale?

Your task: given the code changes made in this session, find which of the project's documents are now wrong and report exactly how to fix them. You produce a brief; the user applies the edits. You do not touch any file.

Cheap orientation, injected — uncommitted changes, staged changes, and recent history:

- Uncommitted vs HEAD (stat):
!`git diff HEAD --stat 2>/dev/null | tail -40 || echo "no git repo or no uncommitted changes"`
- Staged (stat):
!`git diff --staged --stat 2>/dev/null | tail -40`
- Recent commits (a session's work is often already committed):
!`git log --oneline -15 2>/dev/null || echo "no git history"`

If there are uncommitted or staged changes, those are your primary signal. **If the working tree is clean but recent commits exist, the session's changes were committed — do NOT conclude "nothing to sync."** In Step 1 you'll establish the session's commit range and diff that instead. Stop only when there is genuinely no recent activity: no diff *and* no recent commits.

## Step 1 — change intake

First, settle what range to diff. If the injected stat showed uncommitted/staged changes, that's your range (`git diff HEAD`, `git diff --staged`). If the working tree was clean but there are recent commits, the session's work was committed — establish a base: use the session transcript's first timestamp (located below) with `git log --since=<session-start>` to find the session's commits, or fall back to the most recent commit(s) shown in the injected log, and diff that range (`git diff <base>..HEAD`).

From the chosen range, identify the changed files and the symbols/commands/paths likely touched. For files that look documentation-relevant (config, entry points, public API, CLI flags, scripts, build/test commands, env vars, schemas), pull the full hunks yourself with read-only Bash — `git diff <range> -- <file>`. Pull selectively; don't dump the entire diff into context.

Then locate the current session transcript for *intent* (why a change was made, not just what): find the most-recently-modified `.jsonl` under `~/.claude/projects/` for this project — `ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -5`, pick the one whose path encodes this working directory. Skim it only for decisions that explain the diff (a renamed flag, a dropped dependency, a changed default). This mirrors how `session-usage-analyzer` locates the session JSONL. If you can't find or read it, note that in "What I didn't check" and proceed on the diff alone — the diff is the primary signal.

## Step 2 — enumerate the docs

Glob the project's documentation surface (repo-relative): `**/CLAUDE.md`, `README*`, `CHANGELOG*`, `docs/**/*.md`, `**/*.md` at sensible depth, plus any API-reference or `examples/` directories. Skip `node_modules`, vendored, and build output. Keep the candidate list tight.

## Step 3 — triage each doc against the changes

For each changed symbol/command/path from Step 1, Grep the doc set for references to it. A doc is a candidate only if it references something the diff changed. Read the candidate docs (only those) and decide per doc: **stale** (the doc now contradicts the code) or **orthogonal** (the change doesn't touch what the doc claims). Most internal changes are orthogonal — that's the expected, correct result for a refactor.

Every staleness call must quote the doc line AND the contradicting code line. If you can't show both, it isn't `[verified]` — downgrade it (`[inferred]`/`[speculative]`) or drop it.

## Step 4 — emit the brief

Return this exact section order. Plain markdown, no emojis. Cap at ~700 words — the user wants concrete editable diffs, not prose.

### 1. Question
One sentence: "Which docs did this session's changes (`<short summary of the change>`) make stale?"

### 2. Findings
Per affected doc, a numbered entry: `<doc path>:<line> — <what's now wrong>. [<confidence>]` followed by the evidence pair (quote the stale doc line, then the contradicting diff/code line). Lead with `[verified]` contradictions in load-bearing docs (CLAUDE.md, README). If nothing is stale, write "No docs affected — the session's changes are orthogonal to existing documentation" and skip to §4.

### 3. Docs affected (ranked)
Bulleted, highest blast-radius first: `- [<confidence>] <doc> — <one-line why it matters>`. This is the at-a-glance triage.

### 4. What I didn't check
**Required.** Docs you didn't open, diff hunks whose doc impact was ambiguous, generated docs you can't verify against source, the transcript if it wasn't locatable, anything external (live links, downstream repos). Name at least 2–3 honest gaps; if scope was genuinely tight, say so explicitly.

### 5. Open questions
Phrased as questions — ambiguous cases where you couldn't tell if a doc should change, or where the change's intent was unclear from diff + transcript.

### 6. Next actions
Per affected doc, a paste-ready fix the user can apply directly:

````
**<doc path>**
```diff
- <stale line>
+ <corrected line>
```
````

Imperative, concrete, ≤1 block per doc. If no docs are affected, write "none — docs are in sync with this session's changes."

## Confidence tags

- **[verified]** — the code change directly contradicts a quoted doc line; both quoted.
- **[inferred]** — the change likely affects the doc but requires a bridging step; state the bridge.
- **[speculative]** — might matter, weak evidence; flag it, don't lead with it.

## Guardrails

- **Propose, never edit.** No Write/Edit. The brief's diffs are for the user to apply.
- **Quote both sides or it's not verified.** No staleness claim without the doc line and the contradicting code line.
- **Orthogonal is a valid result.** Don't manufacture findings to fill the brief.
- **Read sparingly.** Stat → Grep → Read only candidates. Don't dump the full diff or read every doc.
- **Bash is read-only** — `git diff`/`log`/`show`, `ls`, `cat`. Never mutate.
- **Save location:** default behavior is to return the brief to the conversation, not write a file. Only if the user asks to save it, write under the current project (e.g. `.claude/artifacts/doc-sync-<date>.md`) unless they name a path.
