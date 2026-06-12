# claude-kit

Max's personal Claude Code kit — subagents, references, install scripts. Synced across Mac and Windows.

## What's here

```
agents/        Claude Code subagents (drop-in for ~/.claude/agents/)
commands/      Claude Code slash commands (drop-in for ~/.claude/commands/)
skills/        Claude Code skills (drop-in for ~/.claude/skills/, one dir per skill with SKILL.md)
references/    Reference docs that inform agent design
scripts/       Per-OS install scripts + the statusline-command renderers (deployed to ~/.claude/)
```

## Install

```bash
git clone git@github.com:mbschenked/claude-kit.git
cd claude-kit
```

**Mac / Linux:**

```bash
bash scripts/install-mac.sh           # add new agents, leave others alone
bash scripts/install-mac.sh --prune   # also remove stale agents not in this repo
```

**Windows (PowerShell):**

```powershell
.\scripts\install-win.ps1            # add new agents, leave others alone
.\scripts\install-win.ps1 -Prune     # also remove stale agents not in this repo
```

The install scripts copy `agents/*.md`, `commands/*.md`, and each `skills/<name>/` directory into the right Claude Code config directories for the OS (`~/.claude/{agents,commands,skills}/` or `%USERPROFILE%\.claude\{agents,commands,skills}\`). Re-run after a `git pull` to update.

`--prune` / `-Prune` makes the destination mirror the repo exactly — useful after deleting an agent here. **Without** the flag, files in the destination that aren't in this repo are left alone (safe if you have agents from other sources).

## Updating

Add or edit agents in `agents/`, commit, push. Pull on the other machine and re-run the install script.

## Subagents

| Agent | Purpose | Tools | Source |
|---|---|---|---|
| `subagent-design-reviewer` | Review a proposed subagent's design before implementation. Critiques scope, tool grants, trigger clarity, role overlap, and known anti-patterns. Returns a structured verdict. Read-only. | Read, Glob, Grep | Custom |
| `skill-design-reviewer` | Audit a proposed skill bundle (SKILL.md frontmatter + body + references + bundled scripts) against Anthropic's skills doc and captured rules. Returns a source-grounded critique with verdict. Reviews skills given to it; does NOT propose new skills or write files. Parallel to `subagent-design-reviewer`. | Read, Glob, Grep, WebFetch | Custom |
| `project-optimizer` | Audit an existing Claude Code project for context-budget and primitive-fit efficiency. Reviews skills, subagents, slash commands, plugins, hooks, and CLAUDE.md against best-practice rules, then proposes specific changes. Read-only — diagnoses and recommends, does not edit. Pairs with the ProjectOptimizer charter at `<ClaudeCode>/ProjectOptimizer/CHARTER.md` (loaded via Glob; charter is optional deep reference). Distinct from `subagent-design-reviewer` / `skill-design-reviewer`, which review a single proposed design pre-implementation. | Read, Glob, Grep, Bash | Custom |
| `session-usage-analyzer` | Analyze how a single session used its skills, subagents, workflows, and plugins — turn by turn, and versus what was available to the main agent — then return ranked recommendations to improve efficiency and work process. Read-only; composes on the `session-report` plugin's `analyze-sessions.mjs --json` for metrics and parses the transcript itself for the workflow/plugin breakouts it omits. Distinct from `project-optimizer` (whole-project config audit) and `/save` (1–5 grade); does not generate the HTML report. | Read, Glob, Grep, Bash | Custom |
| `research-scout` | Default research agent: takes a question, does the messy fetching/reading/grepping in isolation, returns a 6-section brief with `[verified/inferred/speculative]` confidence tags and `[T1/T2/T3]` source-tier flags. Pairs with the `research-brief` skill (preloaded). For code-repo questions, also reads `.gitignore` / `.gitmodules` / `.git/logs/HEAD` / root config files. Memory at `~/.claude/agent-memory/research-scout/`. | WebFetch, WebSearch, Read, Grep, Glob | Custom |
| `research-analyst` | Heavier-weight counterpart to `research-scout`. Produces long-form multi-section reports (executive summary, detailed findings, methodology note, sources, open questions, recommendations) for strategic / comprehensive / multi-source analysis. Use when narrative breadth matters more than tight discipline. | Read, Grep, Glob, WebFetch, WebSearch | Adapted from [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) (`categories/10-research-analysis/research-analyst.md`), hardened — removed forbidden cross-agent invocation patterns, mock JSON progress numbers, and fictional "Communication Protocol" templates |
| `game-developer` | Implement/optimize game systems in UE5 (C++) or Unity (C#) — gameplay, ECS, profiling, physics, AI, netcode. Profile-first discipline; bounded against `cpp-pro`. | Read, Write, Edit, Bash, Glob, Grep | Adapted from [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) (`categories/07-specialized-domains/game-developer.md`), hardened — removed context-manager handshake + cross-agent section + capability inventory; tightened triggers |
| `cpp-pro` | Modern C++ (C++20/23) language craft — templates, RAII/memory, concurrency, build, graphics, **Unreal-flavored C++**. Complements `game-developer` (owns C++ mechanics, not game-system design). | Read, Write, Edit, Bash, Glob, Grep | Adapted from [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) (`categories/02-language-specialists/cpp-pro.md`), hardened — removed handshake/cross-agent/inventory; **added UE5 C++ scope** (not upstream) |
| `refactoring-specialist` | Restructure code without changing observable behavior — test-first, incremental, behavior-preserving. Not for bugs (→ `debugger`) or features. | Read, Write, Edit, Bash, Glob, Grep | Adapted from [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) (`categories/06-developer-experience/refactoring-specialist.md`), hardened — removed handshake/cross-agent/inventory; **rewrote "commit frequently" → forbid auto-commit/push** |
| `debugger` | Debugging specialist for errors, test failures, and unexpected behavior. Layers failing-test-first + one-variable-at-a-time + 3-strikes hard stop on top of the Anthropic canonical. **Sonnet validation pending** — Opus 4.7 dogfood on Unity C# passed; pair with `/code-review` (Pattern A) for patches heading to source; not autonomous on production bugs. | Read, Edit, Bash, Grep, Glob | Anthropic canonical subagent + 3 systematic-debugging disciplines |
| `prompt-engineer` | Design, optimize, test, evaluate prompts — incl. Claude Code subagent/skill system prompts and agentic prompts. Bounded against `subagent-design-reviewer` (owns wording, not whole-design critique). | Read, Write, Edit, Glob, Grep | Adapted from [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) (`categories/05-data-ai/prompt-engineer.md`), hardened — removed handshake/cross-agent/inventory + Bash; broadened to agentic prompts |
| `ui-designer` | Visual interface design — hierarchy, type, color/contrast, spacing, responsive, motion, a11y — incl. static sites & portfolio pages. Produces specs/CSS/tokens. | Read, Write, Edit, Glob, Grep | Adapted from [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) (`categories/01-core-development/ui-designer.md`), hardened — removed "mandatory" handshake + cross-agent + Bash; scaled down to portfolio scope |
| `technical-writer` | Developer-facing docs — READMEs, setup/getting-started, CLAUDE.md, usage/reference. Verified-commands rule baked in. Bounded against `design-doc` skill & marketing copy. | Read, Write, Edit, Glob, Grep, WebFetch, WebSearch | Adapted from [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) (`categories/08-business-product/technical-writer.md`), hardened — removed handshake/cross-agent/inventory; scoped triggers; wired WebFetch into verify step |
| `webgl-creative-coder` | Implement/debug browser creative-coding pieces — Three.js, raw WebGL2, GLSL, canvas 2D, p5.js — esp. single-file art studies with no build step. Owns graphics mechanics (shader math, noise/fbm, blending, 60fps/draw-call budgets, dpr/rAF/reduced-motion discipline). Bounded against `ui-designer` (art direction), `game-developer` (engines), `frontend-design` skill (app UIs). | Read, Write, Edit, Bash, Glob, Grep | Custom — built 2026-06-10 after survey confirmed no community WebGL/creative-coding agent exists (VoltAgent, wshobson, claudekit all checked) |

## Slash commands

| Command | Purpose |
|---|---|
| `/pr` | Ship the current change end-to-end: triage git state, pre-flight verify with a fresh subagent (code-review fan-out for code / chrome-devtools real-click smoke for UI), commit with structured HEREDOC message, push, open PR via the github MCP (gh CLI fallback), merge once checks are green, report the chain back. Default end-of-task wrap-up. Guardrails forbid `--no-verify`, `--amend` on published commits, `--force` to shared branches, and silent MCP→CLI fallbacks. |
| `/save` | End the session with a structured grade of how well I applied Anthropic's Claude Code best practices. Five rubric categories scored 1–5 with concrete next-session improvements. |

## Skills

| Skill | Purpose | Source |
|---|---|---|
| `research-brief` | Synthesize a research conversation or web-search session into a structured brief: question, key findings (with confidence tags), sources (with tier flags), what wasn't checked, open questions, next actions. Required "What I didn't check" section is the distinguishing feature. | Custom |
| `summarize` | Targeted summarization of a document, PDF, or transcript into one of three named modes — executive (decision-maker's read), key-points (scannable claims), or decision-log (decided + why + open). Not for naive whole-text compression. | Custom |
| `draft-critique` | Structured pushback on a written draft: audience read, claim-by-claim doubt/reconcile loop, severity-tagged cuts (Critical/Optional/Nit), strengths to preserve, explicit gaps, one-or-two-revision next pass. Borrows the `CLAIM → DOUBT → RECONCILE` pattern from `doubt-driven-development` and severity tags from code-review collections. | Custom |
| `design-doc` | Turn messy input (transcripts, rough notes, voice-memo text, scattered threads, photographed-doc text) into one structured markdown design document / GDD in a single pass. Deliberate-only — does NOT auto-trigger on the word "design"; only when explicitly invoked. The curriculum's reusable design-doc template. | Custom |
| `anki-deck` | Convert a text source (markdown, plain text, URL) into an Anki flashcard deck (`.apkg`). Produces atomic Q/A cards — one fact each — for non-obvious content (rules, gotchas, definitions, decision criteria). Not for cloze, image-heavy sources, or one-shot reference cards. genanki-backed. | Custom |
| `5-whys` | Systematic root-cause-analysis: repeatedly ask "Why?" until the fundamental cause is reached, with evidence at each level. For bug investigation, post-mortems, recurring issues. Ships SKILL.md + 2 examples + 2 reference docs (Toyota origins, software patterns). | Vendored (upstream not retained) |
| `save` | Persist session context to both supabrain (`capture_thought` MCP for cross-session/cross-project memory) and local project memory files. Routes per-item based on cross-project utility; defaults to both when uncertain. **Note:** distinct from the `/save` slash command in `commands/` (which runs a session-grading rubric); same name, different surface. | Custom |
| `skill-creator` | Create new skills, modify and improve existing ones, run evals, benchmark performance with variance analysis, optimize descriptions for trigger accuracy. | Vendored from [`anthropics/skills`](https://github.com/anthropics/skills) @ `f458cee` (single hardening: added explicit `allowed-tools` field) |
| `supabase` | Umbrella router for any Supabase task: Database, Auth, Edge Functions, Realtime, Storage, Vectors, Cron, Queues, client libs (`supabase-js`, `@supabase/ssr`), SSR integrations, auth flows, RLS, CLI, MCP, migrations, security audits, Postgres extensions. | Vendored from [`supabase/agent-skills`](https://github.com/supabase/agent-skills) v0.1.2 |
| `supabase-postgres-best-practices` | Postgres performance and best practices: compact SKILL.md + 27 reference files covering indexes (partial/covering/composite/missing/jsonb), RLS performance, connection pooling, schema design, locks, monitoring, n+1 patterns. Wrong/right SQL with EXPLAIN output. | Vendored from [`supabase/agent-skills`](https://github.com/supabase/agent-skills) v1.1.1 |
| `destiny-style-art` | House conventions for the FunArtTests browser-art studies (Destiny-style CRT/HUD pieces): naming taxonomy, single-file skeleton, CRT/HUD chrome, runtime patterns (dpr cap, canvas-CSS pitfall, reduced-motion), ship protocol. **Project skill** — deploy by copying into a repo's `.claude/skills/`; lives in FunArtTests as `after-orhun-style`. | Custom — extracted from the Director Globe build (2026-06) |
| `refresh-cc-catalog` | Main-session skill that forks to `research-scout` to refresh the ProjectOptimizer §7 catalog against the four canonical upstream sources (Anthropic plugins, Anthropic skills, VoltAgent subagent catalog, shanraisshan workflows). Returns a 6-section diff brief with confidence tags + concrete §7 edit actions; does NOT write to `CHARTER.md` directly. `disable-model-invocation: true` — opt-in via `/refresh-cc-catalog`. Pairs with the `project-optimizer` subagent. | Custom |

## Status line

Cross-machine context-percentage status line. Shows `cwd | model | ctx: <percent>%` with color thresholds: **green** <33%, **yellow** 33–60%, **red** >60% (Max's `/clear` decision trigger).

| File | Purpose |
|---|---|
| `scripts/statusline-command.sh` | Bash renderer — deployed to `~/.claude/statusline-command.sh` by `install-mac.sh` |
| `scripts/statusline-command.ps1` | PowerShell renderer — deployed to `%USERPROFILE%\.claude\statusline-command.ps1` by `install-win.ps1` |

**Wire-up in `settings.json`** (one-time, per machine):

```jsonc
// Mac (~/.claude/settings.json)
{ "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" } }

// Windows (%USERPROFILE%\.claude\settings.json)
{ "statusLine": { "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\statusline-command.ps1" } }
```

Don't edit the deployed copies directly — edit the kit versions and re-run the install script.

## References

| File | Purpose |
|---|---|
| `references/agency-agents-index.md` | Curated index of ~147 third-party subagents from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents). Study reference, not an install target. Reads as: "this kind of subagent has been built well — patterns to borrow." |
| `references/voltagent-workflow.md` | Why many VoltAgent subagents were skipped (multi-agent-orchestration workflow mismatch, not low quality) from the 2026-05-15 investigation, plus a revisit-trigger table for when they become relevant at larger project scale, and the fabricated-metrics evaluation tell. |

## Vendored upstream skills — refresh policy

Skills marked **Vendored from ...** are pinned copies from a trusted upstream repo (e.g. `supabase/agent-skills`). They are kept in this kit so they sync across machines via `git pull`. To refresh:

```bash
# example: refresh the supabase skills from upstream
git clone --depth=1 https://github.com/supabase/agent-skills /tmp/sb && \
  rm -rf skills/supabase skills/supabase-postgres-best-practices && \
  cp -R /tmp/sb/skills/supabase /tmp/sb/skills/supabase-postgres-best-practices skills/ && \
  git diff --stat skills/  # review before committing
```

Read the upstream CHANGELOG before refreshing — vendored versions are pinned for a reason.

## Cross-machine memory

Agent files cross machines via this repo. Durable facts about how to use these agents (when to invoke, why they exist, anti-patterns to watch for) cross via the **supabrain** thought store, accessed by either machine through the `ClaudeCodeConnector` MCP. Local memory at `~/.claude/projects/.../memory/` is **not** synced via this repo — paths are OS-specific.

## Conventions

- Every agent declares an explicit `tools:` field. Missing = sprawling default-all-tools = anti-pattern.
- No subagent spawns another subagent (forbidden by Claude Code).
- Read-only agents (reviewers, explainers) have no `Edit` / `Write` / `Bash` access.
- Run new agent designs through `subagent-design-reviewer` before adding them to this repo.
