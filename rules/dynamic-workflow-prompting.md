# Prompting for dynamic workflows

How to run the **Workflow tool** (script-orchestrated dynamic workflows) well. Dynamic Workflows shipped GA ~2026-05-28: a JS script Claude writes coordinates up to **16 concurrent / 1000 total** subagents per run, results live in script variables (not the context window), runs are **resumable**, and a saved script becomes a rerunnable slash command. Trigger via the `ultracode` keyword, `/effort ultracode` (session-wide), or natural language ("use a workflow") on v2.1.160+.

This file is the operating checklist. The distilled "why" lives in memory `[[reference_dynamic_workflow_practices]]` — read both; don't duplicate edits across them.

## The one rule that drives the rest: you can't steer mid-flight

Workflow execution is **synchronous** — once a fan-out fires, every agent runs to completion before the script (the "lead") reassesses. There is no redirecting an agent mid-task. So control collapses to three moments:

1. **The prompts, up front** — the last real point of control (see prompt-review checkpoint).
2. **Between-phase barriers** — where the script can branch on what came back.
3. **Watching `/workflows`** — kill / resume, nothing finer.

Design as if you get one shot per agent, because you do.

## Before any fan-out

- **Pilot on 2–3 items, then scale.** A workflow wrong on item 1 is wrong 200×; the script scales the mistake without noticing. Validate the shape on a handful first.
- **Bake the verify into the script.** A *fresh* agent refutes the result so no worker grades its own work. Adversarial by default for review/audit work.
- **Schema demands evidence, not a verdict.** Force `{finding, file, line, testOutput|diff}`, never `{passed: true}`. Use the Workflow `schema` option so validation happens at the tool layer and the model retries on mismatch.

## Delegation anatomy — the biggest quality lever

Every task the script hands an agent must carry four things. Vague tasks are the root cause of most failures — they make agents misread scope and duplicate each other:

1. **Objective** — the one outcome, stated as a result not an activity.
2. **Output format** — exact shape (prefer a schema).
3. **Tool / source guidance** — which tools, which paths, which search angle; broad→narrow.
4. **Boundaries** — scope *and* effort. What's out of scope, and how hard to look ("3–10 calls," "stop at first confirmed repro").

## Pipeline by default, barrier only when forced

- **`pipeline(items, stageA, stageB, …)`** is the default for multi-stage work — each item flows through all stages independently, no waiting. Wall-clock = slowest single chain.
- **`parallel(thunks)`** is a **barrier** — it waits for everything. Justified only when stage N genuinely needs *all* of stage N-1 at once: dedup/merge across the full set, early-exit on zero results, or "compare against the other findings." Not justified by "I need to flatten/map first" — do that inside a pipeline stage.
- Filter `null`s (`.filter(Boolean)`) — a thrown stage drops that item to null rather than rejecting the call.

## Lead vs workers (orchestrator-worker, flat, one layer)

- In a dynamic Workflow **the script is the lead** (deterministic control flow); workers are the spawned agents. No agent spawns another — nesting is one level.
- **Prep the lead:** plan before spawning; persist the plan/results to script vars or a file early; encode scaling rules; **synthesize, don't concatenate** the workers' output.
- **Prep workers:** independence by design (distinct prompts/tools/paths so they don't overlap); search broad→narrow; explicit stopping criteria.

## The prompt-review checkpoint (highest ROI)

Because mid-flight steering is gone, **review the prompts before scaling.** The full script is persisted and gated behind approval, so make Claude surface the agent prompts in chat *before* firing Workflow on the full set.

- **Always:** self-review the prompts + pilot on 2–3.
- **Conditionally (worth paying for):** a **2-lens review** — (a) project/domain-accuracy and (b) prompt-engineering quality — but only before promoting a workflow to a **saved `/command`**, where the cost amortizes across reruns. A 2-lens pass on a one-off is the over-engineering trap.

## Effort & cost scaling

- Simple fact-find = 1 agent / 3–10 calls. Comparison = 2–4 agents / 10–15 calls each. Complex = 10+ agents with divided responsibilities.
- Multi-agent runs cost ≈ **15× a single chat's tokens**; tokens explain ~80% of performance variance. **Upgrade the model before doubling the agent count.** Fable 5 / Mythos 5 (June 2026) are tuned for long multi-step autonomous tasks — prefer a model bump over fleet bloat for hard synthesis/verify stages.
- Watch for over-spawning (50 agents for a one-fact query) and reviewer-finds-gaps → over-engineering (flag only correctness/requirement breaks, not style nits).
- A good run **saves as `/<name>`** and is **resumable** — unchanged steps replay from cache on rerun.

## Three prompting techniques worth adopting (from shanraisshan, June 2026)

- **`!command` injection** — prefix a line with `!` to run a shell command and inject its output into the prompt. Use to feed *live* state (a `git diff`, a file list, a build error) into an agent prompt instead of describing it secondhand.
- **`PROACTIVELY` in a subagent description** — including the word biases the host toward auto-invoking the agent at the right moment. Use deliberately; over-using it causes over-trigger (the exact failure the kit's tightened descriptions guard against).
- **`Agent(agent_type)` in the `tools:` field** — restricts *which* subagents an agent may spawn. Relevant for orchestrator-style agents; in this kit, the default remains "no subagent spawns another" unless a specific orchestrator needs it.

## The agent-teams data-contract pattern (for parallel independent work)

When fanning out work whose pieces must fit together (e.g. three components of one feature), have the parallel workers **agree on a shared interface/data-contract before execution**, route each to a **deterministic output path**, and cap resources in frontmatter (`model: haiku`, `maxTurns: N`) for the cheap mechanical arms. The contract up front is what lets independent agents produce mergeable output without mid-flight coordination — which you don't have anyway.

## Anti-patterns

- Firing the full fan-out before piloting or reviewing prompts.
- A worker grading its own output (no fresh-agent verify).
- A schema that accepts a bare boolean verdict.
- A `parallel()` barrier where a `pipeline()` would do — wasted wall-clock.
- Treating reviewer "gaps" as work items when they're style preferences, not correctness breaks.
- Over-trusting upstream "feature" lists or metrics (e.g. some shanraisshan "Hot Features" / star counts read as aspirational) — verify against official docs before codifying.
