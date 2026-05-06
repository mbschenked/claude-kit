# agency-agents — Reference Index

**Source:** https://github.com/msitarzewski/agency-agents (commit `783f6a72`, ~147 agents across 12 divisions, MIT, owned by msitarzewski)
**Indexed:** 2026-05-06
**Purpose:** Quick scan reference for proposing subagents to Max. Not a copy-install task.

---

## Repo at a glance

A growing personality-driven prompt library. Each agent is one markdown file with YAML frontmatter (`name`, `description`, `color`, `emoji`, `vibe`, sometimes `services`) followed by sections like Identity, Mission, Critical Rules, Deliverables, Workflow, Communication Style, Success Metrics. Origin: a Reddit thread, iterated for months.

**Organization:** by domain (`engineering/`, `design/`, `marketing/`, `paid-media/`, `sales/`, `product/`, `project-management/`, `testing/`, `support/`, `spatial-computing/`, `game-development/{cross-engine,unity,unreal-engine,godot,blender,roblox-studio}`, `academic/`, `finance/`, `specialized/`). Filename convention is `<division>-<slug>.md`. The `specialized/` folder is the catch-all and is the largest (~40 files), holding everything from `agents-orchestrator` to `legal-document-review` to `zk-steward`.

**Install model:** `scripts/install.sh --tool claude-code` copies all `.md` files into `~/.claude/agents/`. `scripts/convert.sh` regenerates Cursor `.mdc`, Aider `CONVENTIONS.md`, Windsurf `.windsurfrules`, OpenClaw `SOUL.md`, etc. from the same source. The Claude Code path uses the markdown files **as-is**.

## Author philosophy (paraphrased from README + CONTRIBUTING)

- "Specialists, not generic prompts." Narrow scope, distinct voice, concrete deliverables, measurable success metrics, step-by-step workflow.
- Persona sections (Identity, Communication, Critical Rules) and Operations sections (Mission, Deliverables, Workflow, Metrics) are kept **structurally separate** so the converter can split them per tool.
- Agents may declare external `services` in frontmatter, but "the agent must stand on its own — strip the API calls and there should still be a useful persona, workflow, and expertise underneath."
- Personality is non-negotiable. "Generic 'helpful assistant'" is explicitly an anti-pattern in the contributing guide.
- Multi-agent use is illustrated by named "scenarios" in the README (MVP team, marketing campaign team, paid-media takeover team) — the author thinks of agents as a roster you compose, not auto-route.

## Critical caveat for Max — these are NOT proper Claude Code subagents

After sampling ~10 agents directly, almost none declare a `tools:` field in frontmatter. Of the ones I read, only `marketing/marketing-content-creator.md` did (`tools: WebFetch, WebSearch, Read, Write, Edit`). Without a `tools` field, Claude Code grants the agent **all available tools by default** — exactly the sprawling-tool-access anti-pattern Max wants to avoid. Treat this repo as a library of **system prompts**, not as production-ready subagent configs. Any agent worth pulling needs a `tools:` line added before installing.

The "Tools" column below reports what each agent **actually uses** in its workflow (Bash, Read, etc.) so you can grant exactly that — not what's declared in frontmatter (almost always nothing).

---

## Pairs to note (proposer/critic, builder/tester — strict role separation)

| Pair | Role separation? | Notes |
|---|---|---|
| **Evidence Collector** (testing) ↔ **Reality Checker** (testing) | Strong. Evidence Collector defaults to "find 3-5 issues, FAIL"; Reality Checker defaults to "NEEDS WORK" and explicitly **cross-validates** the QA agent's findings against the actual code. Two layers of skepticism, each with a different floor. | Best-designed pair in the repo. Models the dev-loop pattern Max keeps asking about. |
| **Workflow Architect** (specialized) ↔ **Reality Checker** (testing) | Strong. Architect explicitly states: "I do not write code. I do not make UI decisions." Spec gets handed to Reality Checker for verification against actual code; Architect cannot mark spec Approved without that pass. | Architect/verifier separation is encoded in the prompt. |
| **Codebase Onboarding Engineer** ↔ **Code Reviewer** (both engineering) | Soft. Onboarding is read-only and explanation-only ("never modify files, generate patches, or change repository state"); Code Reviewer suggests changes but doesn't write them. Different scopes but no explicit handoff. | Could be a clean explainer/critic pair if you author the handoff yourself. |
| **project-manager-senior** → **ArchitectUX** → **Frontend Developer** → **EvidenceQA** → **Reality Checker** | This is the implicit "studio pipeline" pattern the README and Agents Orchestrator both describe. PM produces tasks → architect produces foundation → dev implements → QA checks → integration certifies. | Decent role separation conceptually, but see anti-patterns below. |
| **Discovery Coach** ↔ **Deal Strategist** (sales) | Soft. Discovery Coach designs questions; Deal Strategist scores qualification. Sequential rather than adversarial. | Outside Max's wheelhouse, noted for completeness. |

## Anti-patterns to avoid (flag these to Max)

1. **`specialized/agents-orchestrator.md` — violates Claude Code's no-subagents-spawning-subagents rule.** Its workflow is literally "Please spawn a project-manager-senior agent...", "Please spawn an ArchitectUX agent...", "Please spawn an EvidenceQA agent..." in a loop. Claude Code subagents cannot delegate to other subagents. **Do not install this.** The pattern only works if Max himself runs it from the main thread, treating it as a checklist for sequential top-level invocations.
2. **No `tools:` field in frontmatter on most agents.** Default = all tools. If you adapt any of these for Max, add a `tools:` line listing only what the workflow actually uses. The `engineering-codebase-onboarding-engineer` is read-only by design but would still be granted Edit/Write/Bash without an explicit allowlist.
3. **Frontend Developer scope drift.** The first "Core Mission" section is "Editor Integration Engineering" (WebSocket bridges, editor protocol URIs, sub-150ms RPC) — bolted onto a generic React/Vue/Angular agent. Two agents glued together. Skip or split before using.
4. **Self-grading agents.** `testing-test-results-analyzer`, `testing-tool-evaluator`, and `testing-workflow-optimizer` all evaluate without an explicit external check. Pair them with Reality Checker if Max actually deploys them.
5. **Sprawling personalities.** Several specialized agents (`hospitality-guest-services` 27KB, `loan-officer-assistant` 28KB, `real-estate-buyer-seller` 31KB, `supply-chain-strategist` 32KB, `healthcare-marketing-compliance` 35KB) are essentially handbooks compressed into a single prompt. Diminishing returns past ~10KB.
6. **Vague triggers.** Many agent `description` fields are tag-clouds ("Modern web technologies, React/Vue/Angular...") rather than activation conditions. Claude Code routes by description; vague descriptions = unreliable routing.
7. **The whole roster is voice-first, not tool-first.** Optimized for "give me content like an expert" rather than "do this task with this set of tools." Useful for content/strategy work, weaker for engineering automation where minimal tool grants and deterministic behavior matter most.

---

## Engineering Division (28 agents)

Path: `engineering/`. Strong on language/framework specialists; weaker on minimal-tool discipline.

| Name | Purpose | Tools (used) | Pattern | When for Max |
|---|---|---|---|---|
| **Codebase Onboarding Engineer** | Explain unfamiliar repos with facts only — entry points, code paths, file responsibilities; explicitly read-only | Read, Grep, Bash (read-only) | Strict scope control: "do not suggest code changes, improvements, optimizations… remain strictly read-only." 3-tier output (1-line / 5-min / deep dive). | **Strong fit.** Use when Max picks up an unfamiliar OSS repo during the curriculum's reading week or studies someone else's portfolio code. |
| **Code Reviewer** | PR-style review with priority markers (🔴 blocker, 🟡 suggestion, 💭 nit); teaches, doesn't gatekeep | Read, Grep | Concise (~5KB). Comment template enforces: location, why, suggestion. "Suggest, don't demand." | **Good fit.** Self-review portfolio JS/CSS before shipping a `vN` branch. |
| **Git Workflow Master** | Branching strategy, conventional commits, history cleanup | Bash (git), Read | Pairs naturally with Jira Workflow Steward. | Possible fit for portfolio commit hygiene if Max wants stricter discipline than ad-hoc commits. |
| **Software Architect** | DDD, system design, trade-off analysis | Read | Strategy/design only. | Weak fit — portfolio is too small; Unreal pivot would benefit later. |
| **Security Engineer** | Threat modeling, secure code review | Read, Grep | Adjacent to Code Reviewer. | Low priority for static portfolio. |
| **SRE** | SLOs, error budgets, observability | Read, Bash | Production-system-flavored. | No clear fit. |
| **Database Optimizer** | Query tuning, indexing, slow-query debug | Bash, Read | Postgres/MySQL focused. | No clear fit. |
| **Technical Writer** | Developer docs, API reference | Read, Write | Standard content agent. | Possible fit for journal entries / curriculum write-ups. |
| **Frontend Developer** | React/Vue/Angular UI implementation | Read, Write, Edit, Bash | **Anti-pattern: scope drift** (editor-protocol bridges section bolted on). | Skip — portfolio is vanilla HTML/CSS/JS. |
| **Rapid Prototyper** | POC/MVP fast iteration | Read, Write, Edit, Bash | "Move fast" persona. | Possible fit for curriculum kit experiments. |
| **Backend Architect / AI Engineer / Mobile App Builder / DevOps Automator / Data Engineer** | Generic stack roles | varies | Standard template. | No clear fit. |
| **Senior Developer / Filament Optimization Specialist / CMS Developer** | Stack-specific (Laravel/Livewire, Filament PHP, WordPress/Drupal) | Read, Write, Edit | Niche to those stacks. | No fit. |
| **Autonomous Optimization Architect / Embedded Firmware Engineer / Incident Response Commander / Solidity Smart Contract Engineer / Threat Detection Engineer / WeChat Mini Program Developer / Feishu Integration Developer / Email Intelligence Engineer / Voice AI Integration Engineer / AI Data Remediation Engineer** | Niche/production-ops specialists | varies | Each ~10-15KB, narrow domain. | No fit. |

---

## Testing Division (8 agents) — highest-quality category

Path: `testing/`. Strongest role separation in the repo. The `evidence-collector` ↔ `reality-checker` pair is the model.

| Name | Purpose | Tools (used) | Pattern | When for Max |
|---|---|---|---|---|
| **Evidence Collector** | Screenshot-based QA, requires visual proof, defaults to FAIL | Bash (Playwright), Read | "Screenshots don't lie." Mandatory commands, 3-5 issues minimum, brutal-honest grading. | **Strong fit** for portfolio QA before promoting `index-vN` to live. |
| **Reality Checker** | Final integration cert, defaults to "NEEDS WORK"; cross-validates QA findings | Bash, Read | Explicit cross-check of the prior agent's output. Best-designed verifier in the repo. | **Strong fit** — pair with Evidence Collector for portfolio releases. |
| **Accessibility Auditor** | WCAG, screen reader, keyboard nav | Bash, Read | Concrete checklist-driven. | **Good fit** for portfolio — Max says he cares about quality. |
| **Performance Benchmarker** | Lighthouse, load testing | Bash, Read | Concrete. | **Good fit** for portfolio LCP/CLS work. |
| **API Tester** | Endpoint validation, integration QA | Bash, Read | Standard. | No fit (no APIs). |
| **Test Results Analyzer** | Test output analysis | Read | Self-grading risk. | Skip unless paired. |
| **Tool Evaluator** | Technology assessment | Read, WebFetch | Self-grading risk. | Skip — better to do tool eval yourself for the curriculum. |
| **Workflow Optimizer** | Process improvement | Read | Self-grading risk; sprawling (22KB). | Skip. |

---

## Game Development Division (16 agents) — relevant to Max's Unreal pivot

Path: `game-development/{cross-engine,unity,unreal-engine,godot,blender,roblox-studio}`. The Unreal cluster is the standout for Max.

| Name | Purpose | Tools (used) | Pattern | When for Max |
|---|---|---|---|---|
| **Game Designer** (cross-engine) | Systems design, GDD authorship, economy balancing | Read, Write | Strategy/design, engine-agnostic. | **Strong fit** when Max begins prototyping his game. |
| **Level Designer** (cross-engine) | Layout theory, pacing, encounter design | Read, Write | Strategy/design. | **Good fit** later. |
| **Technical Artist** (cross-engine) | Shaders, VFX, art-to-engine pipeline | Read, Write | Bridges art and engineering. | **Good fit** later. |
| **Game Audio Engineer** (cross-engine) | FMOD/Wwise, adaptive music | Read, Write | Niche. | Later. |
| **Narrative Designer** (cross-engine) | Branching dialogue, lore architecture | Read, Write | Strategy/design. | **Good fit** later. |
| **Unreal Systems Engineer** | C++/Blueprint boundary, GAS, Nanite/Lumen, AAA-grade UE5 | Read, Write, Edit, Bash | **High-quality, precise.** Hard rules ("zero Blueprint Tick"), engine constraints cited (16M Nanite instance cap), build-system gotchas. | **Strongest fit for Unreal pivot** — sharper than docs because it cites the actual gotchas. Keep filed for when curriculum hits game-dev. |
| **Unreal Technical Artist / Multiplayer Architect / World Builder** | Niagara/PCG/Substrate; replication graph; World Partition/HLOD/LWC | Read, Write | Niche-deep, same template style as Systems Engineer. | Later, depending on game scope. |
| **Unity (Architect / Shader Graph Artist / Multiplayer Engineer / Editor Tool Developer)** | ScriptableObjects, DOTS/ECS, URP/HDRP, Netcode | Read, Write | Niche. | Skip if Unreal-bound. |
| **Godot (Gameplay Scripter / Multiplayer / Shader Developer)** | GDScript 2.0, MultiplayerAPI, VisualShader | Read, Write | Niche. | Skip. |
| **Blender Addon Engineer** | bpy, custom operators, asset validators | Read, Write, Bash | Niche-deep. | Maybe — if Max builds a custom asset pipeline. |
| **Roblox (Systems Scripter / Experience Designer / Avatar Creator)** | Luau, retention loops, UGC | Read, Write | Niche. | Skip. |

---

## Academic Division (5 agents) — relevant to research/world-building

Path: `academic/`. Concise (~7-8KB each), confidence-aware, source-citing. Useful for content depth, not engineering.

| Name | Purpose | Tools (used) | Pattern | When for Max |
|---|---|---|---|---|
| **Historian** | Period authenticity, anachronism flagging, material culture | Read, WebFetch | "Name your sources and their limitations." Confidence levels (well-documented / scholarly consensus / debated / speculative) on every claim. | **Possible fit** for game-design lore work or research briefs. Best academic in the set. |
| **Anthropologist** | Cultural systems, kinship, rituals | Read, WebFetch | Same template, anthropology-flavored. | Possible fit for game world-building. |
| **Geographer** | Climate, terrain, settlement logic | Read, WebFetch | Same template. | Possible fit for game world-building. |
| **Narratologist** | Story structure, character arcs, narrative theory | Read, Write | Same template. | **Good fit** for game-design narrative work. |
| **Psychologist** | Personality theory, motivation, cognitive patterns | Read, Write | Same template. | Possible fit for game-character design. |

---

## Specialized Division (40 agents) — mixed bag, includes the orchestrator anti-pattern

Path: `specialized/`. The largest folder. Contains gems and bloat.

| Name | Purpose | Tools (used) | Pattern | When for Max |
|---|---|---|---|---|
| **Workflow Architect** | Map every system path before code is written; tree spec with happy/branch/failure/cleanup | Read, Grep, Bash | **Excellent role discipline.** Explicit collaboration protocol with Reality Checker; "I do not write code, I do not make UI decisions." Discovery audit checklist. | **Strong fit** for any non-trivial automation Max designs (curriculum tooling, custom MCP servers, hooks). |
| **MCP Builder** | Build Model Context Protocol servers | Read, Write, Edit, Bash | Niche but timely. | **Possible fit** — Max is learning to recognize MCP server opportunities. |
| **ZK Steward** | Luhmann Zettelkasten — atomic notes, ≥2 links, validation gate | Read, Write, Edit | Domain-expert switching ("From Munger's perspective…"); validation checklist. Heavy ritual. | **Possible fit** for journal/research workflow if Max wants Zettelkasten discipline. |
| **Agents Orchestrator** | Run a full PM→Architect→Dev→QA→Integration pipeline | Bash, all | **ANTI-PATTERN — violates Claude Code subagent rules.** Spawns other subagents in a loop. | **Do not install.** Useful only as a written workflow for Max to execute manually from the main thread. |
| **Developer Advocate** | DX, community building, devrel content | Read, Write, WebFetch | Content-flavored. | **Possible fit** for portfolio writeups / sharing curriculum progress. |
| **Document Generator** | PDF/PPTX/DOCX/XLSX from code | Bash, Write | Tool-driven. | Maybe — for curriculum artifact polish. |
| **LSP/Index Engineer** | Language Server Protocol, semantic indexing | Read, Write | Niche-deep. | Later, if Max writes a code-intelligence tool. |
| **(28 other specialized agents)** | Domain-specific business workflows: legal, healthcare, real estate, sales outreach, recruitment, supply chain, finance, ML QA, civil engineering, salesforce, n8n governance, regional business navigators (Korean, French), etc. | varies | Mostly 20-35KB handbooks compressed into prompts. | **No clear fit.** Skip — wrong audience for Max. |

---

## Other divisions — scan only, low/no fit for Max's current work

| Division | Notable patterns | Fit for Max |
|---|---|---|
| **Design** (8 agents: UI Designer, UX Researcher, UX Architect, Brand Guardian, Visual Storyteller, Whimsy Injector, Image Prompt Engineer, Inclusive Visuals Specialist) | Whimsy Injector is the most-cited example of personality in the repo. UX Architect bridges design and code. | Whimsy Injector or UX Architect could spice up portfolio polish; otherwise too studio-flavored. |
| **Marketing** (~28 agents) | Content Creator is the **only one I confirmed declares `tools:` in frontmatter.** Many China-platform-specific (Douyin, Xiaohongshu, Bilibili, WeChat OA, Zhihu, Baidu, Kuaishou, Weibo) or Western-platform-specific (Twitter, LinkedIn, Reddit, Instagram, TikTok). | Possible fit if Max ever shares portfolio/curriculum publicly; otherwise skip. |
| **Paid Media** (7) | Account-takeover scenario in README is the cleanest multi-agent example. | No fit. |
| **Sales** (9) | MEDDPICC/SPIN/Sandler frameworks. Good role separation between Discovery Coach and Deal Strategist. | No fit. |
| **Product** (5) | Sprint Prioritizer, Trend Researcher, Feedback Synthesizer, Behavioral Nudge Engine, Product Manager. | Trend Researcher possibly relevant for game-market research later. |
| **Project Management** (6) | Jira Workflow Steward is well-scoped (Jira-anchor gate, branch matrix, validation hook). Studio Producer / Project Shepherd / Studio Operations are sprawling. Senior PM converts specs to tasks. | **Jira Workflow Steward could fit** if Max ever wants stricter Git/PR discipline. Senior PM useful for converting curriculum specs to task lists. |
| **Support** (6) | Support Responder, Analytics Reporter, Finance Tracker, Infrastructure Maintainer, Legal Compliance Checker, Executive Summary Generator. | Executive Summary Generator could compress journal entries; otherwise skip. |
| **Spatial Computing** (6) | XR Interface Architect, macOS Spatial/Metal Engineer, XR Immersive Developer, XR Cockpit Interaction Specialist, visionOS Spatial Engineer, Terminal Integration Specialist. | No fit unless Max revisits AR/VR. |
| **Finance** (5) | Bookkeeper/Controller, Financial Analyst, FP&A Analyst, Investment Researcher, Tax Strategist. | No fit. |

---

## Top picks summary for Max

If Max only ever pulls/adapts a handful, these are the strongest candidates given his current and near-term work:

1. **`engineering/engineering-codebase-onboarding-engineer.md`** — read-only, scope-disciplined, 3-tier output. Drop-in for "explain this OSS repo to me."
2. **`testing/testing-evidence-collector.md` + `testing/testing-reality-checker.md`** — install as a pair. Models the role separation Max cares about, pre-shipping checks for portfolio `vN` releases.
3. **`testing/testing-accessibility-auditor.md` + `testing/testing-performance-benchmarker.md`** — concrete portfolio QA gates (WCAG, Lighthouse).
4. **`engineering/engineering-code-reviewer.md`** — concise, priority-tagged review for self-PR before merging to main.
5. **`game-development/unreal-engine/unreal-systems-engineer.md`** — file away for the curriculum's game-dev pivot. High signal density.
6. **`specialized/specialized-workflow-architect.md`** — when Max starts designing custom MCP servers, hooks, or curriculum automations.
7. **`academic/academic-narratologist.md` + `academic-historian.md`** — when game-design narrative or world-building enters the picture.

For all of them: **add an explicit `tools:` line to the frontmatter** before installing. The repo's defaults grant everything.

---

## Things I did NOT verify (transparency)

- I directly read ~10 agent files. The rest are characterized from the README's `When to Use` summaries plus the consistent template I confirmed across the samples. Tool-usage columns for unread agents are inferred from what their workflow descriptions imply, not from frontmatter.
- I did not read `scripts/install.sh` or `scripts/convert.sh` source — only the README description of what they do.
- Total agent count: README says 144-147 across 12 divisions; I counted ~147 from the README catalog. Close enough.
