---
name: refresh-cc-catalog
description: Refresh the ProjectOptimizer "Installable Artifact Catalog" (§7 of CHARTER.md) by fetching live state from the four canonical upstream sources — official Claude Code plugins, official Anthropic skills, VoltAgent's curated subagent catalog, and shanraisshan's practitioner workflow patterns. Returns a structured diff brief listing added / removed / changed items per source with confidence tags and one-line "what this replaces in §7" annotations. Use whenever the operator asks "refresh the ProjectOptimizer catalog," "what plugins or skills are new," "check upstream for new Claude Code installables," "is my audit catalog stale," or any time ProjectOptimizer's catalog should be brought current before running an audit. The brief returns to main session for operator review — does NOT write to CHARTER.md directly.
disable-model-invocation: true
context: fork
agent: research-scout
---

# Refresh the ProjectOptimizer §7 catalog

Your task: refresh the ProjectOptimizer "Installable Artifact Catalog" (§7 of `CHARTER.md`) by fetching live state from four canonical upstream sources and returning a structured diff brief. The operator in the main session will review your brief and decide what to apply. You do not write to `CHARTER.md` directly — you produce the brief that informs the operator's edits.

## Step 1 — locate the current catalog

Use Glob to find `**/ProjectOptimizer/CHARTER.md` (likely `/Users/mbschenk/ClaudeCode/ProjectOptimizer/CHARTER.md` on Mac or the equivalent under `D:\ClaudeCode\` on Windows). Read §7 in full. Note the catalog's as-of date and the existing rows (plugin, skill, subagent, workflow entries).

If you can't locate `CHARTER.md`, log that in the brief's "What I didn't check" section and proceed using your knowledge-cutoff baseline — that's still a useful pass for the operator.

## Step 2 — fetch the four sources

For each source, identify what is currently present upstream and diff it against §7's rows.

1. **Official Claude Code plugins** — `https://github.com/anthropics/claude-code/tree/main/plugins` (T1). List every plugin directory present today. Flag any whose names appear in §7 but are gone upstream, and any new directories not yet in §7.

2. **Official Anthropic skills** — `https://github.com/anthropics/skills` (T1). List the `skills/` directory entries. Same diff against §7's skill table.

3. **VoltAgent subagent catalog** — `https://github.com/VoltAgent/awesome-claude-code-subagents` (T2). Scan the top-level README's category sections. Surface only entries that look engineering-team-curated quality — skip low-effort or unmaintained submissions per Max's standing source-preference rule. Cross-reference against §7's "Highest-value picks" subagent list.

4. **shanraisshan workflow patterns** — `https://github.com/shanraisshan/claude-code-best-practice` (T2). Check the `#how-to-use` section and the workflow-collections table for any new methodologies or pattern catalogs added since §7's as-of date.

If a source returns an unexpected layout or 404s, log it in "What I didn't check" and move on. Don't block the brief on one bad fetch.

## Step 3 — produce the brief

Return your standard 6-section research-brief format. Cap the brief at 800 words. The operator wants concrete editable rows, not prose.

1. **Question.** State the refresh question and §7's current as-of date.
2. **Key findings.** Per source: tight list of added / removed / changed items. Each finding carries a confidence tag `[verified / inferred / speculative]` AND a one-line "what this replaces or competes with in §7" annotation. If a new entry has no obvious slot in §7, say so — that signals the catalog's structure needs updating, not just a new row.
3. **Sources.** All four URLs with tier flags `[T1]` / `[T2]`.
4. **What I didn't check.** Required, not optional. List sources that failed, sections you skipped, judgment calls you deferred to the operator.
5. **Open questions.** Anything ambiguous about whether to add or remove a row — experimental status, missing description, unclear adoption signal.
6. **Next actions.** Concrete diffs to apply to §7. Each action names the table, the row, and the change. Example: "In the official plugins table, add row: `| **new-plugin** | <one-line purpose> | SITUATIONAL |`" or "Update §7's as-of date from 2026-05-23 to <today>." This section is the operator's edit checklist.

Keep the brief tight. Expect compact diffs, not full rewrites — if the draft is heading past 800 words, you are padding.
