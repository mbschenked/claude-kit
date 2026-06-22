---
title: "Skills & Subagents Catalog Delta — June 2026"
subtitle: "Anthropic · VoltAgent · shanraisshan — what changed since 2026-05-28, with adoption verdicts and dynamic-workflow recommendations"
date: 2026-06-19
baseline: 2026-05-28
author: ClaudeKit catalog review
---

# Skills & Subagents Catalog Delta — June 2026

**Window reviewed:** 2026-05-28 (last §7 refresh) → 2026-06-19.
**Sources:** Anthropic (`anthropics/skills` + `anthropics/claude-plugins-official` + Claude Code docs) · VoltAgent (`awesome-claude-code-subagents`) · shanraisshan (`claude-code-best-practice`).
**Method:** read-only research-scout fan-out + raw-file reads of every candidate agent. Confidence tags: `[verified]` = read directly this session; `[inferred]` = derived from listings/commits; `[speculative]` = unconfirmed.

---

## 1. Executive summary

The headline isn't a new agent — it's a **platform shift**. **Dynamic Workflows went GA (~2026-05-28)**: script-orchestrated fan-out of up to 16 concurrent / 1000 total subagents, results kept out of the context window, resumable, and saveable as slash commands. That reframes "better prompting for dynamic workflows" from a technique into operating a real orchestration runtime — captured as a new kit asset (`rules/dynamic-workflow-prompting.md`) and a new §7 orchestration tier.

Three things to act on:

1. **Four clean VoltAgent agents are worth adopting** — `mcp-developer`, `cli-developer`, `first-principles-thinking`, `api-documenter`. All hardened and added to the kit this pass. The rest of the ~23 new agents are team/infra/enterprise mismatches or carry the same context-manager-handshake / fabricated-metric anti-patterns that got most of the May batch skipped.
2. **shanraisshan added genuinely useful prompting craft** — `!command` injection, `PROACTIVELY` triggers, `Agent(agent_type)` tool restriction, and an agent-teams data-contract pattern. Folded into the new asset.
3. **One flag for your decision:** `content-quality-editor` is the cleanest new agent structurally, but it does the exact job (`unslop`-based AI-tell stripping) that your global CLAUDE.md *deprecated* `ai-writing-auditor` for. Left unadopted pending your call.

Anthropic's skills repo is essentially unchanged (still 17); the action there is the platform features, not new installables.

---

## 2. Per-source deltas

### 2a. Anthropic (T1) — platform-level

| Item | What changed | Confidence | Relevance |
|---|---|---|---|
| **Dynamic Workflows GA** | New first-class primitive (~05-28). ≤16 concurrent / 1000 total subagents; results in script vars; resumable; saved → slash command. Trigger: `ultracode` / `/effort ultracode` / `/deep-research` / "use a workflow" (v2.1.160+). Needs v2.1.154+. | verified | **High** — already in your environment; drives the prompting asset + §7 tier. |
| **`/deep-research`** | First bundled workflow command — adversarial multi-source research → cited report. | verified | High — candidate replacement for ad-hoc research fan-outs. |
| **Fable 5 / Mythos 5** | New model family (06-09), tuned for long multi-step autonomous tasks. Fable 5 (`claude-fable-5`) public; Mythos 5 restricted. | verified | High — preferred `model:` for hard workflow-orchestration stages. |
| **`claude-api` skill refresh** | Updated 06-09 with Fable 5 / Mythos 5 IDs, scheduled deployments, vault env-var credentials. | verified | Medium. |
| **`frontend-design` skill refresh** | Updated 06-07. | verified | Low. |
| **`project-artifact` plugin** | New (06-19): living HTML status page for multi-workstream projects → `claude.ai/code/artifact/…`. Needs the Artifact tool (Team/Enterprise beta). | verified | Situational. |
| **anthropics/skills count** | Still 17; none added/removed since baseline. | verified | — confirms no install action needed there. |

Sources: `code.claude.com/docs/en/workflows` · `claude.com/blog/introducing-dynamic-workflows-in-claude-code` · `anthropic.com/news/claude-fable-5-mythos-5` · `github.com/anthropics/skills/commits/main` · `github.com/anthropics/claude-plugins-official/commits/main`.

### 2b. VoltAgent (T2) — catalog grew ~131 → ~154 agents

New agents cluster in **04-quality-security** (~8: accessibility-tester, ad-security-reviewer, chaos-engineer, gdpr-ccpa-compliance, penetration-tester, powershell-security-hardening, qa-expert, ui-ux-tester), **06-developer-experience** (~6: build-engineer, cli-developer, dependency-manager, **mcp-developer**, powershell-module-architect, powershell-ui-architect, visual-asset-generator), and **08-business-product** (assumption-mapping, backlog-grooming, content-quality-editor, growth-loops). [verified by directory listing]

**No structural improvement:** the fabricated-performance-metrics flavor text and context-manager JSON handshakes that flagged the May batch are still present in many new agents. [verified by raw-file read] A 06-15 commit removed VoltAgent branding from the README — possible governance change. [inferred]

Sources: repo README + per-category trees + raw files (see adoption matrix §3 for the files actually read).

### 2c. shanraisshan (T2/T3) — richest for the dynamic-workflow ask

| Item | What it is | Confidence |
|---|---|---|
| **`agent-teams/` directory** *(new)* | Concrete pattern: data-contract negotiation between parallel teammates, parallel-component independence, deterministic output routing, frontmatter resource caps (`model: haiku`, `maxTurns: 3`). | verified |
| **Five named macro-workflows** | Superpowers, Everything Claude Code, Matt Pocock Skills, Spec Kit, gstack — all converge on **Research → Plan → Execute → Review → Ship**. | verified |
| **`!command` injection** | `!`-prefixed line runs a shell command and injects output into the prompt — feed live state (git diff, build error) instead of describing it. | inferred (in README; matches real CC feature) |
| **`PROACTIVELY` trigger** | The keyword in a subagent description biases auto-invocation. | inferred |
| **`Agent(agent_type)` restriction** | In the `tools:` field, restricts which subagents may be spawned. | inferred |
| **"Hot Features" list + star counts** | Lists ~20 features (`/sandbox`, `/focus`, `/advisor`, Auto Mode, etc.); some look aspirational and star counts look inflated. | speculative — **do not cite uncritically.** |

Repo is actively maintained but mostly via automated daily chore commits; human content additions aren't cleanly datable. Sources: repo README + `agent-teams/agent-teams-prompt.md` + `best-practice/claude-subagents.md` + repo tree.

---

## 3. Adoption verdict matrix (VoltAgent new agents)

Judged against the kit's standing rules: explicit minimal `tools:`, no context-manager JSON handshakes, no fabricated-metric templates, read-only reviewers. All rows `[verified from raw file]` unless noted.

| Agent | Tools | Anti-patterns present? | Verdict | Reason |
|---|---|---|---|---|
| **mcp-developer** | Read,Write,Edit,Bash,Glob,Grep | context-mgr opener + handshake + fake metrics (stripped) | **ADOPTED** | Only purpose-built MCP agent; fills May gap. |
| **cli-developer** | Read,Write,Edit,Bash,Glob,Grep | handshake + fake metrics (stripped) | **ADOPTED** | CLI design for kit/UE5/portfolio tooling. |
| **first-principles-thinking** | Read,Grep,Glob,WebFetch,WebSearch (read-only) | only cross-agent prose (stripped) | **ADOPTED** | Clean reasoning agent; no overlap with research-scout. |
| **api-documenter** | Read,Write,Edit,Glob,Grep,WebFetch,WebSearch | handshake + fake metrics (stripped); Write now scoped to docs | **ADOPTED** | OpenAPI + examples; complements technical-writer. |
| **content-quality-editor** | Read,Write,Edit,Bash | none structurally | **FLAG — your call** | Does the `unslop` AI-tell-stripping job your CLAUDE.md deprecated `ai-writing-auditor` for; `unslop` not installed. |
| **accessibility-tester** | Read,Grep,Glob,Bash (read-only) | likely context-mgr block (line ~95, unconfirmed) | **DEFER** | Confirm the block; adopt only if shipping a11y-sensitive web. |
| **penetration-tester** | Read,Grep,Glob,Bash (read-only, Opus) | context-mgr opener; rest unread | **DEFER** | Portfolio pre-launch security sweep. |
| **llm-architect** | Read,Write,Edit,Bash,Glob,Grep (Opus) | — | **DEFER** | Overlaps prompt-engineer; only for real LLM pipelines. |
| **embedded-systems** | Read,Write,Edit,Bash,Glob,Grep | cross-agent list | **DEFER** | Only for hardware targets. |
| **dependency-manager** | Read,Write,Edit,Bash,Glob,Grep | **wired context-mgr JSON + hard-coded `vulnerabilities_fixed: 23` etc.** | **SKIP** | Worst offender; structural rewrite needed. |
| **ui-ux-tester** | +chrome-mcp,computer-use | **wired context-mgr JSON; hard runtime deps** | **SKIP** | Team-orchestration design; deps you don't run. |
| **build-engineer** | Read,Write,Edit,Bash,Glob,Grep | context-mgr opener + fake % targets | **SKIP** | JS/monorepo framing ≠ UE5 build (UBT/CMake). |
| **qa-expert** | Read,Grep,Glob,Bash | context-mgr opener + baked coverage % | **SKIP** | Enterprise QA; overlaps code-review-worker + tdd-generator. |
| **chaos-engineer** | Read,Write,Edit,Bash,Glob,Grep | context-mgr opener | **SKIP** | No distributed-systems surface for a solo dev. |
| **search-specialist** | read-only | — | **SKIP** | Overlaps research-scout. |
| **scientific-literature-researcher** | +mcp\_\_bgpt | BGPT MCP dependency | **SKIP** | Inert without the BGPT MCP. |

All infrastructure (18 agents) and pure data-platform/ML agents: **SKIP** — no signal for a solo dev without production backend.

---

## 4. Recommended new workflows (recommendations only — not built)

Now that Dynamic Workflows are native, three are worth authoring as saved `/commands` when the moment comes. Cost amortizes across reruns, so build only when a workflow will be re-run.

1. **`refresh-catalog`** — promote the exact 4-source delta scan run for this report into a one-command pipeline: fan out one research agent per source → an adoption-verdict stage scoring each new agent against the kit's rules → a synthesized brief. Highest value; this report was assembled by hand and would be one command next time. Pairs with the existing `refresh-cc-catalog` skill (which already forks a research-scout) — the workflow generalizes it to also produce verdicts.
2. **`agent-adoption-bakeoff`** — given a candidate upstream agent, fan out three lenses (harden-it / score-vs-kit-rules / check-overlap-with-existing) → synthesis verdict. Mirrors the proven `tdd-bakeoff.js` pattern already in GameMakerKit.
3. **`portfolio-prelaunch-sweep`** — chain the two DEFER reviewers (`accessibility-tester` + `penetration-tester`) as a gated pre-launch check when the portfolio ships. Read-only; one command, two perspectives.

Prompting discipline for all three: see §5 and `rules/dynamic-workflow-prompting.md`.

---

## 5. Better prompting for dynamic workflows (summary)

Full guide: **`ClaudeKit/rules/dynamic-workflow-prompting.md`**. The load-bearing points:

- **You can't steer mid-flight** — execution is synchronous. Control collapses to (1) the prompts up front, (2) between-phase barriers, (3) `/workflows` kill/resume. So the **prompt-review checkpoint** before scaling is the highest-ROI move.
- **Delegation anatomy** — every delegated task carries Objective · Output format · Tool/source guidance · Boundaries (scope *and* effort). Vague tasks are the #1 failure cause.
- **Pilot on 2–3, then scale.** A workflow wrong on item 1 is wrong 200×.
- **Bake the verify in** (a fresh agent refutes), and make the **schema demand evidence** (test output / diff / line ref), never a bare `{passed:true}`.
- **`pipeline()` by default; `parallel()` only when a stage truly needs all prior results** (dedup, early-exit, cross-comparison).
- **Upgrade the model before doubling the agent count** — tokens explain ~80% of perf variance; Fable 5 / Mythos 5 suit hard synthesis/verify stages.
- New craft folded in from shanraisshan: **`!command`** live-state injection, **`PROACTIVELY`** triggers, **`Agent(agent_type)`** spawn restriction, and the **agent-teams data-contract** for mergeable parallel output.

---

## 6. Open questions & what wasn't verified

- **`unslop` maintenance / macOS-arm64 support** — unconfirmed; it's not currently installed, so `content-quality-editor` would be inert. Decision needed on whether AI-tell stripping belongs in the kit at all (vs. the deprecated `ai-writing-auditor`).
- **`accessibility-tester` line-95 context-manager block** — flagged but not read verbatim; confirm before any adoption (could flip DEFER → SKIP).
- **`penetration-tester` / `qa-expert` body tails** — only first ~50 lines read; SKIP/DEFER verdicts stand but the full bodies weren't audited.
- **shanraisshan "Hot Features" dates & star counts** — not separable from automated commits; treat the list as aspirational until cross-checked against the official changelog.
- **`project-artifact` install path** — present in the `plugins/` dir but not confirmed in `marketplace.json` (so `/plugin install` may not yet resolve it), and it needs the Artifact beta regardless.
- **Unchecked VoltAgent depth** — `01-core-development`, `03-infrastructure`, `05-data-ai` raw files largely unread (dismissed as not-solo-relevant by category); a silent useful addition there is possible but unlikely.
- **CHARTER.md duplicate** — a second copy exists at `ClaudeCode/claude-kit/ProjectOptimizer/CHARTER.md`; only the canonical `ClaudeCode/ProjectOptimizer/CHARTER.md` was updated this pass.
