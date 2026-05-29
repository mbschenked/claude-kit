# ProjectOptimizer — doctrine repo for the read-only efficiency-consultant subagent

This directory holds the **doctrine** for the ProjectOptimizer subagent. It is *not* where the subagent runs from — it's where the source-of-truth lives and where the human-facing PDF is rendered.

## What's here

| File | Role |
|---|---|
| `CHARTER.md` | **Source of truth.** Full doctrine — five-check audit protocol, workflow patterns, installable catalog. Markdown so it's diffable. |
| `ProjectOptimizer-Charter.generated.pdf` | Rendered deliverable. `.generated.pdf` suffix signals "derived from CHARTER.md, do not edit directly." |
| `render_pdf.py` | Re-renders the PDF from CHARTER.md via Chrome headless. Idempotent. |
| `.claude/` | Project-scope Claude Code settings (currently unused). |

## Where the subagent actually lives

The subagent file and the catalog-refresh skill are not in this directory — they live in the [`claude-kit`](../../ClaudeKit/) repo so they sync across Mac and Windows:

- Subagent canonical: `~/ClaudeKit/agents/project-optimizer.md` (edit here)
- Subagent deployed: `~/.claude/agents/project-optimizer.md` (overwritten by `install-mac.sh` / `install-win.ps1` — never edit here)
- Skill canonical: `~/ClaudeKit/skills/refresh-cc-catalog/SKILL.md`
- Skill deployed: `~/.claude/skills/refresh-cc-catalog/SKILL.md`

## After editing CHARTER.md

```bash
python3 render_pdf.py
```

Writes `ProjectOptimizer-Charter.generated.pdf`. Takes a few seconds. Output is reproducible — no random elements.

## The non-obvious gotcha

**CHARTER.md and the subagent file (`~/ClaudeKit/agents/project-optimizer.md`) hold the doctrine in two places.** CHARTER.md is the long-form human-readable source; the subagent file embeds a condensed version inline so the agent doesn't have to fetch the charter at runtime.

**If you change doctrine in CHARTER.md, propagate the relevant bits to the subagent file too** — otherwise the PDF and the running agent diverge silently. This is intentional (runtime efficiency > strict single-source) but it means the subagent file is a *second* edit, not a derived artifact.

The opposite direction is easier: if you tweak the subagent file directly, the doctrine in CHARTER.md is the canonical reference — bring CHARTER.md back into sync next time you sit down with this project.

## Memory

Project-scope memory lives at `~/.claude/projects/-Users-mbschenk-ClaudeCode-ProjectOptimizer/memory/`. Key files: role definition, audit methodology, charter delegation pattern, artifact locations, source list. Always check there first for context.

## Verification

This is a doctrine/writing project, not a code project — no tests, no build pipeline. The closest thing to "does it work" is:

1. `python3 render_pdf.py` exits 0 and produces an 8-ish-page PDF.
2. The subagent is invocable: type `/agents` in a Claude Code session and `project-optimizer` should appear.
3. `/refresh-cc-catalog` is recognized as a skill.

If any of those three fail, something upstream broke — likely the `install-mac.sh` didn't deploy the latest kit state, or the agent/skill file has a frontmatter error.
