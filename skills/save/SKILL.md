---
name: save
description: Save the important context, decisions, references, and outstanding work from the current conversation to both supabrain (cross-session memory via the ClaudeCodeConnector capture_thought MCP tool) and local project memory files. Invoke when the user types `/save` or asks to save/persist the conversation.
---

# /save — capture conversation to supabrain + local memory

When invoked, follow these steps in order. Keep work tight; the user wants persistence, not narration.

## 1. Triage — is there anything worth saving?

First, decide whether the conversation contains anything that meets at least one of these bars:

- A durable fact about the user, their setup, or their preferences that wouldn't already be inferable from the project state
- A decision or piece of context that would be lost if not captured (and that matters beyond this turn)
- A pointer to an external resource, file, or system worth referencing later
- Validated feedback or a non-obvious approach the user confirmed worked

If nothing clears that bar, **stop here**. Tell the user plainly: "Nothing in this conversation looks worth saving — [one-line reason]. Let me know if you want me to save something specific anyway." Do not write anything. Do not manufacture content to justify a save.

Common cases that don't clear the bar: routine code edits where the change speaks for itself, Q&A whose answer is in the docs, tool/feature exploration with no new conclusion, debugging that's already encoded in the resulting fix.

If there are items worth saving, categorize each:

- **User profile** — biographical facts, role, expertise, preferences, working style
- **Feedback** — corrections, or non-obvious approaches the user validated
- **Project state** — decisions, status, deadlines, motivations specific to the current working directory
- **References** — pointers to external systems, files, dashboards, repos, accounts, or resources
- **Cross-cutting facts** — things useful beyond this project (conventions the user uses everywhere, recurring tools, broad preferences)

If the user passed extra text after `/save`, treat it as a hint about what to focus on (e.g., `/save the auth decision` → emphasize that decision).

## 2. Decide destination per item

- **Supabrain only** (`capture_thought`) — items useful across many projects: biographical, durable preferences, big decisions, important external references, cross-project state.
- **Local memory only** — items specific to the current project/working directory that won't matter elsewhere.
- **Both** — milestones, durable decisions, project setups worth recalling even when working in a different repo.

Default to **both** when uncertain. Duplication is cheap; missing context is expensive.

## 3. Write to supabrain

For each supabrain-bound item, call `mcp__claude_ai_ClaudeCodeConnector__capture_thought`. One call per distinct idea — do **not** bundle unrelated facts into a single thought.

Each thought should have:

- **content**: a tight paragraph or two. Facts and decisions, not transcript. Lead with the durable claim. Include *why* when known so future sessions can judge edge cases.
- **metadata**: object with
  - `type`: one of `observation`, `decision`, `task`, `reference`, `feedback`
  - `people`: array, e.g. `["Max"]`
  - `topics`: 2–4 tags (e.g. `["claude-code", "memory", "skills"]`)
  - `action_items`: list of concrete follow-ups, or `[]`
  - `dates_mentioned`: absolute `YYYY-MM-DD` strings — convert relative dates ("Thursday", "next week") before saving

## 4. Write to local memory

Use the memory directory for the current working directory:
`~/.claude/projects/<cwd-with-slashes-replaced-by-dashes>/memory/`

Follow the existing memory-system convention:

- One file per memory, named semantically (e.g. `user_role.md`, `project_curriculum.md`, `feedback_testing.md`).
- Frontmatter on every memory file:
  ```
  ---
  name: <memory name>
  description: <one-line description used to judge relevance later — be specific>
  type: <user | feedback | project | reference>
  ---
  ```
- For `feedback` and `project` entries, structure the body as: rule/fact, then a `**Why:**` line and a `**How to apply:**` line.
- Update `MEMORY.md` (the index) with a single-line pointer per memory: `- [Title](file.md) — one-line hook`. Don't write memory content into `MEMORY.md` itself.
- **Update existing memories** rather than creating duplicates. Check the index first.

## 5. Archive the session (ClaudeOptimizer)

After the memory writes, bank the session into the ClaudeOptimizer corpus by invoking the
**`session-archive`** skill (it writes a metrics-stamped card + raw-transcript copy + ledger row).

This step is **additive and best-effort** — it must never block or fail `/save`'s core function:

- If `session-archive` reports it skipped (ClaudeOptimizer not present on this machine, or `node`
  missing), that's fine — note it in the report and move on.
- If it errors, surface the one-line error and continue; do **not** retry in a loop or abort the save.
- If a best-practices grade for this session is already known (e.g. the `/save` grading command ran),
  pass it through; otherwise let `session-archive` omit the grade.

## 6. Report

Return a brief summary, under ~15 lines, structured like:

```
Saved to supabrain:
- <one line each — content type + topic>

Memory files written/updated:
- <path or filename — what it captures>

Archived to ClaudeOptimizer:
- <card path, or "skipped — <reason>">

Skipped (intentionally):
- <one line each, only if non-obvious>
```

The user wants to confirm it worked, not re-read the conversation.

## Guardrails

- Convert all relative dates to absolute `YYYY-MM-DD` before saving.
- **Never save secrets, API keys, tokens, or credentials.** If a useful fact references one, save the fact and note the secret lives in a referenced location instead.
- Never save full transcripts — always summarize.
- If a supabrain or memory write fails, surface the error to the user rather than silently swallowing it; offer to retry.
- Don't duplicate a memory the index already covers — update in place.
