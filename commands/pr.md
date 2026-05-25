---
description: Ship code — pre-flight verify, commit, push, PR, merge. Default end-of-task wrap-up.
---

# /pr — ship the current change

End-of-task workflow that takes implemented code from "works on my machine" to merged main. Run after implementation is complete and Max has eyeballed the result. The steps below are MANDATORY in order — do not skip, even under time pressure.

If the user passed extra text after `/pr` (e.g., `/pr feature-branch-name`, `/pr base=develop`, `/pr no-merge`), treat it as a hint about scope or branching, but never as license to skip guardrails.

## 1. Triage — read the room before touching anything

Run in parallel:
- `git status --short` — what's dirty?
- `git log --oneline -5` — recent commit cadence
- `git rev-parse --abbrev-ref HEAD` — current branch
- `git remote -v` — where does this push to?
- `gh pr list --state open --json number,title,headRefName,baseRefName` — any open PR already covering this branch?

Then read the project's CLAUDE.md if not already loaded this session. Watch for:
- A rule requiring explicit user confirmation before pushing to a specific branch.
- Auto-deploy (GitHub Pages / Vercel / Netlify / etc.) — pushes that ship publicly.
- Required pre-push checks (tests, type-check, lint).
- Conventional commit / merge-method preferences.

If the target branch is auto-deployed (or otherwise CLAUDE.md-gated) and the user hasn't authorized the push in this turn, **stop and confirm** before proceeding. Authorization once does NOT mean authorization always.

## 2. Pre-flight verify — fresh subagent, not self-audit

The implementer false-passes its own work. Verification is delegated.

**For code changes:**
- Code-review fan-out (parallel `code-review-worker` subagents on 4 distinct axes — correctness, security, maintainability, project-constraints) is the default for substantive diffs.
- Slim 2-axis fan-out is acceptable for tight scope (one file, ≤50 lines, clearly bounded).
- Single-arm review is only acceptable for one-line / typo-class changes.

**For UI / interaction changes:**
- A fresh subagent loads the page in a real browser (chrome-devtools MCP).
- Real click via uid from snapshot — never `evaluate_script` to invoke JS handlers directly. Programmatic clicks bypass hit-testing and false-pass occluded or z-index'd bugs.
- Console must be clean — zero errors, zero relevant warnings.
- Test the golden path AND one edge case (reload state, second click, accent variant, mobile width, etc.).

**If verification finds a bug**, fix it first. Re-verify with a fresh subagent run (cache-busted — instruct the subagent to hard-reload). Do not commit until pre-flight is clean. `/pr` exists to ship known-good work, not to ship and hope.

If verification is genuinely N/A (docs-only, copy-only, config file with no runtime surface), state that explicitly in the report and skip — but the bar is "no runtime surface", not "I'm confident enough".

## 3. Commit — structured message, HEREDOC

- Stage explicitly by filename. Never `git add -A` or `git add .` — those can sweep up secrets, lock files, or unrelated work-in-progress.
- Compose the commit message as: one-line subject (under 70 chars, imperative voice) + blank line + body grouped by area. Each area gets 1–4 specific bullets that name the file or system touched.
- Always include the `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` trailer.
- Always use HEREDOC for the commit message — preserves formatting and avoids shell-quoting bugs.

```bash
git add path/to/file1 path/to/file2 && git commit -m "$(cat <<'EOF'
Short imperative subject under 70 chars

Area A (file or system name):
- specific change with file path
- another specific change

Area B:
- ...

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

**Never:**
- `--no-verify` — pre-commit hooks exist for a reason; fix the issue, don't bypass it.
- `--amend` on a published commit.
- `-c commit.gpgsign=false` or any flag that bypasses signing.

If a hook fails: investigate the root cause, fix it, re-stage, **create a NEW commit**. Do not `--amend` a failed commit — the commit didn't happen, so amend would modify the previous (already-published) one.

## 4. Push — branch, never force

```bash
git push -u origin <branch>
```

- Never `--force` or `--force-with-lease` to a shared branch without explicit user confirmation in this turn.
- Never push directly to a protected branch (typically `main`) if the project gates main behind PR review (check CLAUDE.md + branch protection).
- If the branch already tracks origin, `-u` is harmless; if not, it sets up tracking.

## 5. PR — github plugin first, gh CLI fallback

Try the github MCP first:

```
mcp__claude_ai_Direct_Github_Connection__create_pull_request
  owner, repo, head, base, title, body
```

If the MCP returns **403 Resource not accessible by integration** (or any permission error), fall back to `gh pr create` — and **report the fallback in user-facing text** rather than silently retrying. Integration drift is worth knowing about.

**PR body template:**

```markdown
## Summary

[1–3 bullets — the "why" and the "what changed", grouped by area if the diff spans multiple concerns. Tighter than the commit message body.]

## Test plan
- [x] Pre-flight already run (list — runtime smoke / code-review fan-out / etc.)
- [ ] Anything that requires post-merge confirmation (Pages deploy, CI canary, prod smoke)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

Use HEREDOC for the body if shelling out to `gh pr create`.

## 6. Merge — only when checks are green

- If required checks are configured, wait for them. If checks are pending and the project has branch protection, do not bypass.
- Use the project's conventional merge method (merge / squash / rebase). When in doubt, ask once or default to plain `merge`.
- Try `mcp__...merge_pull_request` first; fall back to `gh pr merge <num> --<method>` on 403.

After merge:
```bash
gh pr view <num> --repo <owner>/<repo> --json state,mergedAt,mergeCommit
```
Confirm `state: MERGED` and capture the merge SHA in the report.

## 7. Report

Return ≤15 lines:

```
Pre-flight: <one line — what subagent ran, what it confirmed>
Commit:     <SHA> — <subject>
Push:       <branch> → origin
PR:         <URL> — opened via <MCP | gh CLI>
Merge:      <state> at <SHA> via <merge | squash | rebase>
Post-merge: <one line — what's expected downstream (Pages deploy, CI, etc.)>
```

If anything was skipped or fell back to a non-default path (MCP→CLI, no fan-out due to trivial scope, etc.), surface it in the report so the user can spot drift.

## Guardrails recap

| Hard rule | Why |
|---|---|
| Pre-flight verification by a fresh subagent | Implementer false-passes own work |
| `--no-verify` / `--no-gpg-sign` forbidden | Hooks and signing exist for a reason |
| `--amend` on published commits forbidden | Rewrites shared history |
| `--force` to shared branches forbidden without turn-level confirmation | Destroys others' work |
| `git add -A` / `git add .` forbidden | Can sweep secrets or unrelated WIP |
| Explicit user confirmation before pushing to a CLAUDE.md-gated branch | Respects project policy; authorization is scope-bound |
| MCP→CLI fallbacks reported, not silent | User needs to spot integration drift |
| No merge with failing or unrun required checks | Branch protection exists for a reason |

## When NOT to use /pr

- Spike branches, throwaway experiments, scratch repos with no review process — `git commit` + `git push` is enough.
- Multi-PR refactors where you're shipping a series and the per-PR ceremony slows the train — use this on the first and last PR of the series, run lighter in between.
- Hotfix where the user has explicitly said "skip the dance, ship it" — honor the override but still pre-flight verify, still no `--no-verify`.
