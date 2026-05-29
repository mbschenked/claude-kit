---
name: davila7-unrealclaude-analysis
description: GameMakerKit bootstrap — adoption analysis of the davila7 game-development agent set + the Natfii/UnrealClaude UE5 plugin. Agent-readable structured form.
status: draft
audience: agents
subjects:
  - davila7-game-dev-agents
  - natfii-unrealclaude-plugin
sources:
  davila7_repo: https://github.com/davila7/claude-code-templates
  davila7_sha: e42e8ba19c34d5957cf25aab0a358c117716005f
  natfii_repo: https://github.com/Natfii/UnrealClaude
  natfii_sha: 9f12f2edf5484a2da48c675c12a73e4ebe0ae4da
  natfii_bridge_sha: 2d8d957a6a6c525744ed6c48f8f2d27441dae9c8
fetched: 2026-05-27
project_context:
  user: Max Schenk
  role: Combat Designer
  engine: UE5.7 (TBH + TOG, both confirmed)
  strategy: "lean into C++, Python editor scripting, MCP — keep Blueprints human-driven"
related_files:
  vendored_agents: ../agents/_candidates/
  mcp_tool_catalog: ../references/unrealclaude-mcp-tools.md
  unreal_claude_md_template: /Users/mbschenk/ClaudeCode/ClaudeCurriculum/kit/CLAUDE.md.unreal.template
---

# GameMakerKit bootstrap — davila7 agents + UnrealClaude

This document is the adoption-decision substrate for two upstream dependencies the GameMakerKit was opened around. It is **agent-readable** — tabular, action-tagged, machine-parseable. The human-readable narrative version is the sibling `.pdf`. Every recommendation here is **initial signal** for Max's review; nothing is yet deployed to `~/.claude/`.

## Executive summary

| # | Subject | Verdict tag | Reason (1 line) |
|---|---|---|---|
| 1 | `unreal-engine-developer` (davila7) | `#consider-adopt` | UE5 C++/Blueprint specialty agent; fills a real gap in current kit |
| 2 | `game-designer` (davila7) | `#consider-adopt` | Pure-design specialist, orthogonal to existing code agents |
| 3 | `3d-artist` (davila7) | `#optional` | Fits only if art tooling becomes in-scope |
| 4 | `unity-game-developer` (davila7) | `#park` | TBH is parked Unity work; keep available for resume |
| 5 | `game-developer` (davila7) | `#skip` | Cross-platform generic + orchestrator overhead; overlaps existing kit |
| 6 | Natfii/UnrealClaude plugin | `#adopt-as-dependency` | Strong fit with C++/Python-MCP strategy; UE5.7-only matches both projects |

---

# Section 1 — davila7 game-development agent set

**Upstream directory:** `davila7/claude-code-templates/cli-tool/components/agents/game-development/`
**Pinned SHA:** `e42e8ba19c34d5957cf25aab0a358c117716005f`
**Vendored verbatim to:** `GameMakerKit/agents/_candidates/`
**License:** MIT (per upstream `LICENSE`)

## 1.1 Comparison matrix

| Agent | Lines | Domain | Tools (frontmatter) | Standalone vs orchestrator | UE5 fit | Verdict |
|---|---|---|---|---|---|---|
| `unreal-engine-developer` | 131 | UE5 C++ + Blueprint, AAA shipping | Read, Write, Edit, Bash | Standalone | High | `#consider-adopt` |
| `game-designer` | 40 | Genre-agnostic design docs, balance, progression | Read, Write, Edit | Standalone | High (orthogonal) | `#consider-adopt` |
| `3d-artist` | 40 | Engine-neutral 3D asset pipeline, PBR, LOD | Read, Write, Edit, Bash | Standalone | Medium | `#optional` |
| `unity-game-developer` | 113 | Unity 2022.3+ C#, URP/HDRP, mobile | Read, Write, Edit, Bash | Standalone | Low (UE5 focus) | `#park` |
| `game-developer` | 290 | Cross-platform generic | Read, Write, Edit, Bash, Glob, Grep | **Orchestrator** (8 named subagent collaborators) | Low (no UE5 depth) | `#skip` |

## 1.2 Per-agent detail

### 1.2.1 `unreal-engine-developer.md` — `#consider-adopt`

- **Self-described role:** "Expert Unreal Engine developer specializing in C++ programming, Blueprint visual scripting, and AAA game development. Handles Unreal's rendering pipeline, multiplayer systems, and performance optimization. Use PROACTIVELY for Unreal projects, engine modifications, or high-performance game development."
- **Tool grant:** Read, Write, Edit, Bash — appropriate for a coding agent; not over-broad.
- **Standalone:** no orchestrator calls in the system prompt.
- **Gap it fills:** Max's current kit has generic `cpp-pro`, generic `game-developer`, and `code-reviewer`. None of these encode UE5 idioms (UPROPERTY/UFUNCTION reflection, GC handling, replication, Blueprint↔C++ boundary, Lyra-style framework, asset cooking concerns).
- **Quality flags:**
  - ✓ Tight tool scope.
  - ✓ Clear C++-and-Blueprint split (doesn't default to either as sole authority).
  - ⚠ System prompt is "10+ years AAA generalist" — no specific framework awareness (no Lyra reference, no GAS reference). Borrowing patterns from Max's actual projects (TOG/TBH conventions) will need to happen via project-level CLAUDE.md, not the agent.
  - ⚠ Description includes "Use PROACTIVELY" — combined with main session's "use proactively" reflex, this could auto-trigger more than Max wants. Consider tightening on adopt.
- **Action if adopted:** copy `_candidates/unreal-engine-developer.md` → `agents/` (kit-side) → `~/.claude/agents/` (deployed). Strip the `<!--VENDORED-->` header before deploy or leave (harmless). Audit the proactive language.

### 1.2.2 `game-designer.md` — `#consider-adopt`

- **Self-described role:** Mechanics, balancing, player psychology, system design, narrative integration, monetization frameworks; produces GDDs, balance docs, difficulty curves.
- **Tool grant:** Read, Write, Edit (no Bash — correct; pure-design work doesn't execute code).
- **Standalone:** no orchestrator calls.
- **Gap it fills:** Max has zero design-specialist agents. Current kit is all code/research/critique/writing. For a combat designer shipping TOG, a balance/mechanics agent is a real complement.
- **Quality flags:**
  - ✓ Restricted tool scope matches non-coding work.
  - ✓ No overlap with existing agents.
  - ⚠ Genre-agnostic — covers F2P monetization and mobile economy patterns that don't apply to TOG/TBH. Not a blocker; just noise in the system prompt.
  - ⚠ No instrumentation for validating balance claims (how does it test a curve?). For real iteration, pair with playtest data pipeline (out of scope).
- **Action if adopted:** straight vendor + deploy. Lower risk than `unreal-engine-developer` because it can't execute code.

### 1.2.3 `3d-artist.md` — `#optional`

- **Self-described role:** Game-ready 3D modeling, texturing, PBR setup, LOD planning, technical art docs.
- **Tool grant:** Read, Write, Edit, Bash. The Bash grant is for asset-pipeline tooling (Blender CLI, FBX SDK, etc.).
- **Standalone:** no orchestrator calls.
- **Gap it fills:** none today. Max's combat-designer role doesn't currently include in-house 3D pipeline ownership; TOG art is outsourced or carried by team.
- **Decision deferred:** revisit if (a) Max takes on tech-art work, (b) art pipeline tooling enters the kit, (c) outsource review becomes a recurring need.
- **Park location:** stay in `_candidates/` indefinitely; surface on workflow trigger.

### 1.2.4 `unity-game-developer.md` — `#park`

- **Self-described role:** Unity 2022.3 LTS+ C# specialist; mobile, console, PC; ECS, save/load, AI.
- **Tool grant:** Read, Write, Edit, Bash.
- **Standalone:** no orchestrator calls.
- **Gap it fills:** TBH was Unity. If TBH resumes or any Unity-side reference work surfaces, this agent is ready. Today, dormant.
- **Park location:** `_candidates/` until TBH revives.

### 1.2.5 `game-developer.md` — `#skip`

- **Self-described role:** Cross-platform generic — ECS, graphics, physics, AI, networking; aims for sub-3s load, 60 FPS, <100ms latency across mobile/console/PC/web.
- **Tool grant:** Read, Write, Edit, Bash, **Glob, Grep** — broadest grant in the set.
- **Standalone vs orchestrator:** **Orchestrator pattern.** Explicitly names 8 subagent collaborators (frontend-developer, backend-developer, performance-engineer, mobile-developer, devops-engineer, qa-expert, product-manager, ux-designer). Spinning this up would cascade into work the kit doesn't have.
- **Why skip:**
  - Overlaps with Max's existing generic `game-developer.md` (already in kit).
  - Overlaps with `unreal-engine-developer` if both adopted; the UE-specific one wins on every UE5 axis.
  - The 8-subagent orchestrator design is a wrong-shape import for a single-developer kit. Max's orchestration pattern is small-fan-out (`/code-reviewer` fan-out, Pattern A/B prompt chaining) — not 8-role agile team simulation.
  - No UE5-specific guidance to compensate for the breadth tax.

## 1.3 davila7 adoption decision rule

Recommended adoption profile for first deploy: **two agents** (`unreal-engine-developer` + `game-designer`). Defer `3d-artist`. Park `unity-game-developer`. Drop `game-developer` entirely (keep in `_candidates/` as a vendoring record only; do not deploy).

---

# Section 2 — Natfii/UnrealClaude UE5 plugin

**Upstream:** `https://github.com/Natfii/UnrealClaude`
**Pinned SHA:** `9f12f2edf5484a2da48c675c12a73e4ebe0ae4da`
**Companion MCP bridge:** `Natfii/ue5-mcp-bridge` @ `2d8d957a6a6c525744ed6c48f8f2d27441dae9c8` (separate repo, bundled as submodule)
**License:** MIT
**Engine:** **UE5.7 exclusively** — no 5.5 backport per maintainer; matches both TBH and TOG.
**Last commit:** 2026-05-16 (11 days before this analysis); 7 open issues.

## 2.1 Component inventory

| Component | Path in repo | What it is |
|---|---|---|
| Plugin manifest | `UnrealClaude/UnrealClaude.uplugin` | Standard UE5 plugin descriptor |
| Plugin source | `UnrealClaude/Source/UnrealClaude/` | C++ plugin code (HTTP handler, editor integration) |
| MCP bridge | `UnrealClaude/Resources/mcp-bridge/` | Git submodule pulling `Natfii/ue5-mcp-bridge` (Node/TS) |
| CLAUDE.md template | `UnrealClaude/CLAUDE.md.default` | Conventions doc (one dir deep, not at repo root) |
| Plugin config | `UnrealClaude/Config/` | Default settings |
| License | `LICENSE` | MIT |

**Not shipped:** prebuilt binaries (must build per platform — Win64, Linux, macOS-AS verified by maintainer); separate Python editor scripting layer.

> **Note on path:** The Phase 1 exploration assumed `CLAUDE.md.default` was at repo root. It's actually at `UnrealClaude/CLAUDE.md.default`. Update any future install scripts accordingly.

## 2.2 Runtime model

1. **On editor launch:** plugin auto-starts, spins up an MCP HTTP server on `localhost:3000`, registers in-editor chat widget under `Tools → Claude Assistant`.
2. **Claude Code CLI integration:** point at the running server via `/mcp` slash command. Same tool surface as the in-editor chat.
3. **Tool dispatch:** Direct calls for read-only and simple writes (`unreal_status`, `unreal_asset_search`, `unreal_spawn_actor`). Domain-routed calls through a `unreal_ue` router with a `domain:` parameter for complex/stateful ops (blueprint modify, anim, character, enhanced-input, material).
4. **Concurrency:** max 4 concurrent MCP tasks; subagent fan-out capped at 3 (leaving 1 slot for lead). Read-only safe to parallelize, per-object-safe parallelizable across distinct actors/assets, sequential-only ops (`open_level`, `delete`, `execute_script`) must run alone.
5. **Timeouts:** game-thread ops 30s · default task 2min · async bridge 5min. Watchdog detects OneDrive/Dropbox sync hangs at 60s.
6. **Editor close:** server shuts down with editor.

Full tool catalog: see `references/unrealclaude-mcp-tools.md` (29 tool/domain rows, safety-class tagged).

## 2.3 Capability delta

### What Claude Code can do WITH UnrealClaude that it can't WITHOUT

1. **Asset-graph queries at scale** — `unreal_asset_search`, `unreal_asset_dependencies`, `unreal_asset_referencers`. Reference chains and impact analysis across hundreds of assets without parsing `.uasset` binaries.
2. **Level introspection + actor manipulation** — `unreal_get_level_actors`, `unreal_spawn_actor`; spawn, configure, move, delete.
3. **Blueprint structural reads + bounded writes** — `unreal_blueprint_query` reads; the `unreal_ue` router with `domain: blueprint` adds/modifies variables and functions. (Caveat in §2.5.)
4. **Material parameter querying + modification** — through `unreal_ue` router (`domain: material`).
5. **Editor Python automation** — `unreal_execute_script` (sequential-only). Claude writes + executes Python in the editor context, chaining operations across UE's Python API.
6. **Doc-driven dev** — plugin auto-injects custom `CLAUDE.md` + project modules/plugins/settings into Claude's system prompt at session start.

### What Claude Code STILL CAN'T DO even with UnrealClaude

1. **Modify C++ source directly** — only Live Coding scope. Cannot edit `.cpp/.h` and recompile the plugin itself.
2. **Node-level Blueprint graph wiring** — adding variables and functions works; complex node-to-node wiring is flagged by upstream's own CLAUDE.md as having known bugs ("don't rely on fully").
3. **Direct Reflection API queries** — no meta-query tools; only pre-wrapped MCP endpoints.
4. **Multi-instance / network-play testing** — MCP is single-editor; no multi-agent orchestration over distributed PIE.

## 2.4 Fit assessment against Max's strategy

Max's stated UE strategy (from PLAN.md and supabrain): **"lean into Unreal's three AI-friendly surfaces — C++, Python editor scripting, MCP — while keeping Blueprints as the human-driven layer."**

UnrealClaude maps as follows:

| Strategic surface | UnrealClaude fit |
|---|---|
| C++ | Partial — read good (asset/level/source-tree query), write limited (Live Coding scope only) |
| Python editor scripting | **Strong** — `unreal_execute_script` is exactly this surface |
| MCP | **Strong** — that's literally what it is |
| Blueprint = human-driven | **Compatible** — UnrealClaude can read Blueprints freely; its write capabilities are bounded (and acknowledged buggy), which aligns with keeping Blueprints in human hands by default |

**Net:** strong alignment. The "Blueprint mutation is buggy" caveat is actually consistent with Max's strategy rather than a problem — the design intent is for Blueprint authorship to stay with humans.

## 2.5 Risks + gotchas

| Risk | Severity | Mitigation |
|---|---|---|
| Blueprint mutation has known bugs (upstream's own admission) | Medium | Use Blueprint-write tools sparingly; prefer query for now |
| UE5.7-only; no 5.5 backport coming | None for TBH/TOG | Both projects already on 5.7 |
| Build-per-platform; no prebuilt binaries | Low (one-time setup cost) | Document the build steps in `/gamemaker-onboard` flow |
| MCP bridge requires `npm install` after clone | Low | Document in onboard flow |
| Large-project latency on initial context injection | Medium | Plugin streams modules/assets at session start — can be slow on TOG-scale projects |
| OneDrive/Dropbox file sync hangs MCP at 60s | Low (Max not on OneDrive for TBH/TOG per memory) | Avoid syncing the project root |
| Blocker issue open upstream: "Claude cannot read Blueprints or use other custom tools" | Unknown impact | Check issue status before deploy; may be already fixed in next release |
| Maintainer is single-developer indie effort; bus-factor of 1 | Long-term | Vendor the plugin + bridge SHAs in the GameMakerKit so a project pins a known-good combo |

## 2.6 Adoption recommendation

**`#adopt-as-dependency`** — UnrealClaude is the right plumbing for Max's UE5 strategy. Concretely:

- **Don't bundle the plugin into ClaudeKit/GameMakerKit** — it's a UE plugin, not a Claude artifact. ClaudeKit ships the *integration knowledge* (this analysis, the MCP tool catalog, the agent guidance), not the plugin binary.
- **Document it as the recommended UE-side companion** — GameMakerKit's README and `/gamemaker-onboard` flow point users at it.
- **`/gamemaker-onboard` checks for it** — at project onboarding, the command detects whether `Plugins/UnrealClaude/` exists in the target UE project; if absent, offers the clone + build path.
- **`unreal-engine-developer` agent (Section 1.2.1) should know about it** — adopt-time customization: append a short "When working in projects with UnrealClaude installed, prefer `unreal_*` MCP tools over filesystem reads for `.uasset` assets" rider to the agent's system prompt. Keeps the agent useful in both UnrealClaude-equipped and bare projects.

---

# Section 3 — Implications for `/gamemaker-onboard` (preview)

This section is **forward-looking**. Full command spec lives in `commands/gamemaker-onboard.md` (stub this pass). Documented here so the analysis hangs together with the kit's design direction.

## 3.1 Onboard command — checks it will perform

1. **Detect project type** — read `*.uproject` to confirm UE5, parse `EngineAssociation` for version.
   - If not UE5.7 → warn that UnrealClaude won't work; offer to proceed with agent set only.
2. **Detect UnrealClaude plugin presence** — check `Plugins/UnrealClaude/UnrealClaude.uplugin`.
   - If absent → offer the clone-and-build flow; document the manual steps if Max declines automation.
3. **Detect existing project CLAUDE.md** — if present, offer merge guidance; if absent, offer to drop `CLAUDE.md.gamemaker.template` with project-specific placeholders pre-filled.
4. **Confirm agent allowlist** — show which GameMakerKit agents would be available; let Max accept/decline the default set (Section 1.3).
5. **Verify MCP wiring** — if UnrealClaude is installed and editor is running, hit `http://localhost:3000/mcp/status` to confirm bridge is alive.

## 3.2 Onboard command — what it will NOT do (intentional)

- Will not auto-modify the `.uproject` file.
- Will not install the UnrealClaude plugin without explicit confirmation per step.
- Will not write to anywhere outside `<project_root>/CLAUDE.md` and `<project_root>/.claude/`.

---

# Section 4 — Skills + featureDev question

Per Max's request: "skills to make sure it specialises in game dev behavior might be necessary" + "featureDev subagent might also be useful to add here as long as its given skill to push it out of default behavior."

## 4.1 Game-dev-flavored skills — proposed inventory (deferred)

Not built this pass. Initial candidate list for later evaluation:

| Candidate skill | Purpose | Priority |
|---|---|---|
| `ue5-anti-patterns` | Reference list for `code-reviewer` to apply on UE5 C++ (raw pointer to UObject, missing UPROPERTY, blocking game-thread, etc.) | High |
| `gameplay-ability-system-patterns` | If TOG uses GAS, codify common GA/GE/AS shapes for review + scaffolding | Conditional on Max's GAS use |
| `combat-system-conventions` | Encode the TOG-specific posture/deflect/stance system idioms for cross-session continuity | High for TOG, N/A for TBH |
| `unreal-network-replication-rules` | Cross-check for Replicated UPROPERTY + RPC categories + relevance | Medium |

## 4.2 featureDev subagent question — recommendation

**Defer the decision.** Max disabled the `feature-dev` plugin during the 2026-05-25 plugin cleanup (per memory `reference_active_plugins_inventory`) and that decision held. Re-importing the subagent alone (without the plugin's command/hook surface) would require:

1. Fetching the upstream `feature-dev` subagent source.
2. Auditing it against `subagent-design-reviewer` for scope-creep, tool-overgrant, and orchestrator-hidden anti-patterns.
3. Writing the "push it out of default behavior" skill Max referenced — likely a UE-specific feature-design skill that constrains the agent to UE patterns.

That's a meaningful chunk of design work that should run as its own pass, not bundled into this bootstrap. Surfaced here so Max can prioritize.

---

# Section 5 — What ships this pass · what doesn't

**Ships (this PR):**

- This analysis MD + its narrative PDF sibling.
- 5 vendored davila7 agents in `_candidates/` with provenance headers (read-only review surface).
- UnrealClaude MCP tool reference catalog (`references/unrealclaude-mcp-tools.md`).
- Stub `commands/gamemaker-onboard.md` (spec only).
- Stub `templates/CLAUDE.md.gamemaker.template`.
- `GameMakerKit/README.md`.
- One entry in curriculum `kit/workflows-index.md`.

**Does not ship (intentional):**

- Any deploy to `~/.claude/agents/` or `~/.claude/commands/`.
- Install-script extension for sub-kit traversal (deferred until Max confirms agent set).
- Game-dev-flavored skills (Section 4.1 — separate pass).
- featureDev subagent decision (Section 4.2 — separate pass).
- Live `/gamemaker-onboard` implementation (stub only).
- UnrealClaude plugin clone or install into TBH/TOG (decision deferred to Max).

**Next decisions for Max:**

1. Confirm or amend Section 1.3 adoption profile (`unreal-engine-developer` + `game-designer`; defer `3d-artist`; park `unity-game-developer`; drop `game-developer`).
2. Confirm UnrealClaude adoption strategy (Section 2.6 — adopt-as-dependency, not as bundled plugin).
3. Pick which proposed skills from Section 4.1 to schedule next.
4. Decide featureDev (Section 4.2) — re-import or stay-removed.
