# ProjectOptimizer — doctrine source (synced via ClaudeKit)

This folder is the **synced copy** of the ProjectOptimizer doctrine, carried inside `claude-kit` so it travels to every machine on `git pull`. The runnable pieces deploy separately via the kit's install script:

- Subagent: `../agents/project-optimizer.md` → deployed to `~/.claude/agents/project-optimizer.md`
- Skill: `../skills/refresh-cc-catalog/` → deployed to `~/.claude/skills/refresh-cc-catalog/`

So **the agent runs from the kit install alone** — it embeds a condensed doctrine. This folder provides the long-form reference the agent reads when present.

## Files

| File | Role |
|---|---|
| `CHARTER.md` | Source of truth — full five-check audit protocol, workflow patterns, installable catalog. |
| `ProjectOptimizer-Charter.generated.pdf` | Rendered human-facing deliverable (derived from CHARTER.md). |
| `render_pdf.py` | Re-renders the PDF from CHARTER.md via Chrome headless. Run `python3 render_pdf.py` after editing the charter. |
| `CLAUDE.md` | Project notes (written for the standalone `~/ClaudeCode/ProjectOptimizer` workshop; paths there are Mac-specific). |

## How the agent finds this charter

`agents/project-optimizer.md` locates the charter at session start with `Glob **/ProjectOptimizer/CHARTER.md` (case-sensitive — that's why this folder is `ProjectOptimizer`, not `project-optimizer`). If found, it reads it once for the catalog and citations; if not, it proceeds on embedded doctrine and notes the degraded scope in its output.

## Bringing up a new machine

1. Clone `claude-kit`, run `scripts/install-mac.sh` (or `install-win.ps1`) → agent + skill deployed.
2. This folder rides along in the clone → charter source + render script available immediately.

> The standalone `~/ClaudeCode/ProjectOptimizer` repo on the original Mac remains the local render workshop. Keep this copy in sync when the charter doctrine changes there (and remember the agent file embeds a condensed version — see CLAUDE.md's "non-obvious gotcha").
