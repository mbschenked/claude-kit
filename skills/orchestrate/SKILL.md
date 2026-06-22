---
name: orchestrate
description: Run an interactive pre-flight (explore → grill you via grill-me → propose a plan → audit it with /audit-plan to pick the best-fit subagents/skills per slot) then launch a deterministic multi-agent build pipeline (implement → iterative independent review → fix) for one coding task via `/orchestrate <task>`. Slash-only; an explicit multi-agent run.
disable-model-invocation: true
allowed-tools: Task, Skill, Workflow
---

# Orchestrate a build pipeline

`/orchestrate <task>` has two halves: an **interactive pre-flight you run in this conversation** (explore → grill → propose plan → audit → lock), then an **autonomous build pipeline** launched via the Workflow tool (implement → iterative review → fix). The pre-flight is interactive (it talks to the user through `grill-me` and confirms the audited agent choices); the autonomous pipeline cannot, so every design and primitive decision is settled before it launches.

## What to do when invoked

1. **Objective.** Treat the user's text after `/orchestrate` as the task.
2. **Exploration stage.** Dispatch an **`Explore`** subagent with a prompt that gives it the task and asks it to return draft findings: intended approach, files to touch, risks, and the open questions that need the user's decision. Keep the verbose searching inside the subagent.
3. **Grill stage (interactive, codebase-first).** Present the Explore findings (especially the open questions) in the conversation so they're visible context — `grill-me` takes no arguments and interviews against what's on screen. **For each open question, first try to settle it by reading the code; only genuinely undecided design questions should reach the user.** Then invoke the **`grill-me`** skill to interview the user until you reach shared understanding. This MUST happen here, in the main context — the autonomous pipeline can't ask the user anything.
4. **Propose the plan.** Fold the grill outcomes into an initial plan: approach, files, ordered steps, decisions made.
5. **Audit stage — pick the slot specialists.** Dispatch the **`plan-primitive-auditor`** subagent (the engine behind `/audit-plan`) via Task, **passing the full proposed-plan text in the prompt** — do NOT rely on its default `~/.claude/plans/*.md` discovery; this plan lives in the conversation, not on disk. Give it the pipeline's slots and current defaults (implement = `general-purpose`, review lenses = `code-review-worker`, fix = `general-purpose`) and ask it to recommend the best-fit kit subagent/skill per slot for THIS task — keep the default or swap in a specialist (e.g. `game-developer`, `cpp-pro`, `mcp-developer`, or an extra review lens), each with one-line reasoning. **Require it to return a plain mapping ready for step 7**: `implement: <agentType>`, `fix: <agentType>`, `reviewLenses: [{lens, axis, agentType}]` — omitting any slot it leaves at default. It is read-only / suggest-only — **surface the mapping to the user for a quick confirm or override before launch.**
6. **Lock.** Lock the plan AND the confirmed slot mapping.
7. **Launch the build.** Resolve the pipeline at `${CLAUDE_SKILL_DIR}/pipeline.js` (fall back to Glob `**/skills/orchestrate/pipeline.js`; never hardcode a `~/.claude/...` path). Call the **Workflow** tool with:
   `{ scriptPath: "<path>", args: { task: "<task>", plan: "<locked plan>", effort: "quick"|"balanced"|"thorough", agents: { implement: "<agentType>", fix: "<agentType>", reviewLenses: [ { lens, axis, agentType } ] } } }`
   Pass only the slots the audit actually changed; omit the rest to use the pipeline defaults. Invoking this skill *is* the explicit opt-in the Workflow tool requires.
8. **Relay results.** Summarize the returned result — agents used, rounds run, whether it converged clean (vs. outstanding findings or an inconclusive review), and files changed. Do NOT redo its work.

## Effort

`args.effort` trades cost for rigor: **`quick`** (1 correctness lens, single pass), **`balanced`** (3 lenses, up to 2 review→fix rounds — the default), **`thorough`** (3 lenses, up to 3 rounds). Omit → balanced. Pick per task; default down for small changes.

## Customizing

Defaults live in `pipeline.js` (`EFFORT` / `DEFAULTS` / `LENS_AXES`); per-task slot picks come from the audit step (5). The interactive levers are steps 2/3/5 here.
