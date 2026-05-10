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
| `research-scout` | Default research agent: takes a question, does the messy fetching/reading/grepping in isolation, returns a 6-section brief with `[verified/inferred/speculative]` confidence tags and `[T1/T2/T3]` source-tier flags. Pairs with the `research-brief` skill (preloaded). For code-repo questions, also reads `.gitignore` / `.gitmodules` / `.git/logs/HEAD` / root config files. Memory at `~/.claude/agent-memory/research-scout/`. | WebFetch, WebSearch, Read, Grep, Glob | Custom |
| `research-analyst` | Heavier-weight counterpart to `research-scout`. Produces long-form multi-section reports (executive summary, detailed findings, methodology note, sources, open questions, recommendations) for strategic / comprehensive / multi-source analysis. Use when narrative breadth matters more than tight discipline. | Read, Grep, Glob, WebFetch, WebSearch | Adapted from [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) (`categories/10-research-analysis/research-analyst.md`), hardened — removed forbidden cross-agent invocation patterns, mock JSON progress numbers, and fictional "Communication Protocol" templates |

## Slash commands

| Command | Purpose |
|---|---|
| `/save` | End the session with a structured grade of how well I applied Anthropic's Claude Code best practices. Five rubric categories scored 1–5 with concrete next-session improvements. |

## Skills

| Skill | Purpose | Source |
|---|---|---|
| `research-brief` | Synthesize a research conversation or web-search session into a structured brief: question, key findings (with confidence tags), sources (with tier flags), what wasn't checked, open questions, next actions. Required "What I didn't check" section is the distinguishing feature. | Custom |
| `draft-critique` | Structured pushback on a written draft: audience read, claim-by-claim doubt/reconcile loop, severity-tagged cuts (Critical/Optional/Nit), strengths to preserve, explicit gaps, one-or-two-revision next pass. Borrows the `CLAIM → DOUBT → RECONCILE` pattern from `doubt-driven-development` and severity tags from code-review collections. | Custom |
| `supabase` | Umbrella router for any Supabase task: Database, Auth, Edge Functions, Realtime, Storage, Vectors, Cron, Queues, client libs (`supabase-js`, `@supabase/ssr`), SSR integrations, auth flows, RLS, CLI, MCP, migrations, security audits, Postgres extensions. | Vendored from [`supabase/agent-skills`](https://github.com/supabase/agent-skills) v0.1.2 |
| `supabase-postgres-best-practices` | Postgres performance and best practices: compact SKILL.md + 27 reference files covering indexes (partial/covering/composite/missing/jsonb), RLS performance, connection pooling, schema design, locks, monitoring, n+1 patterns. Wrong/right SQL with EXPLAIN output. | Vendored from [`supabase/agent-skills`](https://github.com/supabase/agent-skills) v1.1.1 |

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
