---
name: audit-plan
description: Audits a draft plan's primitive choices — checks whether each step uses the best-fit skill, subagent, or Workflow, and returns ranked, quality-first suggestions to swap in the right one, flag hand-rolled work an installed agent would do better, spot sequential steps that should be a parallel Workflow fan-out, and catch a Workflow used for a one-off. Read-only; it suggests, never edits the plan. For plan mode once a draft plan with enumerated steps already exists on disk (typically after the Explore agents finish).
when_to_use: Invoke when the user types /audit-plan, says "audit my plan," "are these the right agents/skills for this," "should this step be a workflow," or "review my plan's primitive choices," or when wrapping up a plan in plan mode before ExitPlanMode. Requires a draft plan already written to ~/.claude/plans/ — do not fire on adjacent plan-mode questions when no plan artifact exists yet. NOT for whole-project config audits (project-optimizer), a single proposed agent's design (subagent-design-reviewer), or a finished session (session-usage-analyzer).
context: fork
agent: plan-primitive-auditor
---

# Audit this plan's primitive choices

Your task: audit the current draft plan and return a ranked, quality-first brief on
whether each step uses the best-fit primitive (skill, subagent, Workflow, or inline).
You are read-only — you suggest; the main agent decides what to apply. **Quality is the
priority; efficiency is only the tie-breaker.**

## Step 1 — locate the plan

Use the plan file path provided in your invocation. If none was provided, Glob
`~/.claude/plans/*.md` and audit the most-recently-modified one. Read it in full. If you
were also handed a one-line summary of the Explore findings, use it to understand the
step intents.

If no plan file exists yet, say so plainly and stop — there is nothing to audit until the
draft is written to disk. (The main agent should write the in-context draft to the plan
file first, then re-invoke.)

## Step 2 — run the audit

Follow your full `plan-primitive-auditor` procedure: enumerate the AVAILABLE set of
installed skills / subagents / plugins, classify each step's work-type, pick the best-fit
primitive (quality first, efficiency as tie-breaker), and flag the anti-patterns
(hand-rolling, sequential-inline-that-should-fan-out, over-engineering, missing or vague
delegation).

## Step 3 — return the brief

Return your standard output contract verbatim — the seven sections from
`# Plan Primitive Audit` through `## 7. What I could not determine`, with `[Swap]` /
`[Keep]` / `[Gap]` verdict tags. Sections 6 and 7 are always required. If the plan is
sound, say "no high-leverage changes found" rather than inventing churn.
