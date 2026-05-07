# claude-kit

Max's personal Claude Code kit — subagents, references, install scripts. Synced across Mac and Windows.

## What's here

```
agents/        Claude Code subagents (drop-in for ~/.claude/agents/)
commands/      Claude Code slash commands (drop-in for ~/.claude/commands/)
references/    Reference docs that inform agent design
scripts/       Per-OS install scripts
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

The install scripts copy `agents/*.md` and `commands/*.md` into the right Claude Code config directories for the OS (`~/.claude/{agents,commands}/` or `%USERPROFILE%\.claude\{agents,commands}\`). Re-run after a `git pull` to update.

`--prune` / `-Prune` makes the destination mirror the repo exactly — useful after deleting an agent here. **Without** the flag, files in the destination that aren't in this repo are left alone (safe if you have agents from other sources).

## Updating

Add or edit agents in `agents/`, commit, push. Pull on the other machine and re-run the install script.

## Subagents

| Agent | Purpose | Tools |
|---|---|---|
| `subagent-design-reviewer` | Review a proposed subagent's design before implementation. Critiques scope, tool grants, trigger clarity, role overlap, and known anti-patterns. Returns a structured verdict. Read-only — cannot create or modify files. | Read, Glob, Grep |

## Slash commands

| Command | Purpose |
|---|---|
| `/save` | End the session with a structured grade of how well I applied Anthropic's Claude Code best practices. Five rubric categories scored 1–5 with concrete next-session improvements. |

## References

| File | Purpose |
|---|---|
| `references/agency-agents-index.md` | Curated index of ~147 third-party subagents from [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents). Study reference, not an install target. Reads as: "this kind of subagent has been built well — patterns to borrow." |

## Cross-machine memory

Agent files cross machines via this repo. Durable facts about how to use these agents (when to invoke, why they exist, anti-patterns to watch for) cross via the **supabrain** thought store, accessed by either machine through the `ClaudeCodeConnector` MCP. Local memory at `~/.claude/projects/.../memory/` is **not** synced via this repo — paths are OS-specific.

## Conventions

- Every agent declares an explicit `tools:` field. Missing = sprawling default-all-tools = anti-pattern.
- No subagent spawns another subagent (forbidden by Claude Code).
- Read-only agents (reviewers, explainers) have no `Edit` / `Write` / `Bash` access.
- Run new agent designs through `subagent-design-reviewer` before adding them to this repo.
