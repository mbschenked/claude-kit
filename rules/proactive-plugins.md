# Proactively use the install-floor plugins

These three plugins are installed and enabled. Reach for them by default at the natural moment — don't wait to be asked. The user can always decline.

- **session-report** (`/session-report`) — when a session ran long, felt sluggish, or hit context pressure, generate the report instead of guessing about token spend.
- **commit-commands** (`/commit`, `/commit-push-pr`, `/clean_gone`) — use these for commit / push / PR hygiene rather than hand-rolling git command sequences. (Needs the `gh` CLI.)
- **claude-md-management** (`/revise-claude-md`, `claude-md-improver`) — after a session surfaces a durable convention or correction, offer to fold it into CLAUDE.md; run the improver when a CLAUDE.md looks stale or over-long.
