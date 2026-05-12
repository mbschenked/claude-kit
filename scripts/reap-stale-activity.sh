#!/usr/bin/env bash
# reap-stale-activity.sh — Claude Code Stop hook
#
# Truncates /tmp/claude-activity-${session}.log when the assistant's turn ends.
# At Stop time, no tool can be in-flight (the model has finished generating its
# response), so any row still marked `end == null` in the log is provably stale.
# Truncating clears those plus the recently-completed rows that the statusline
# would otherwise show for 3s — fine, because the user is about to read the
# response itself, not the activity board.
#
# Why this hook exists: log-activity.sh writes end events on PostToolUse, which
# does not fire if the tool process is killed externally (e.g., osascript losing
# its target app, SIGKILL, heredoc truncation). Without a Stop-time reap, those
# rows persist forever (saw a 50-min stale row on 2026-05-12). Stop is the
# authoritative "nothing is running" signal from Claude Code itself.
#
# Wired in ~/.claude/settings.json under "Stop" (matcher omitted — fires every turn).
# Do NOT also wire under SubagentStop — that would erase the parent agent's other
# in-flight rows while a subagent completes.
#
# Deployed by scripts/install-mac.sh to ~/.claude/scripts/reap-stale-activity.sh.
# Edit this file and re-run install-mac.sh, not the deployed copy.

set -uo pipefail

input=$(cat)
session=$(jq -r '.session_id // "unknown"' <<<"$input")

# Defense: refuse to delete anything unless we got a real session id.
if [ -z "$session" ] || [ "$session" = "unknown" ]; then
  exit 0
fi

LOG="/tmp/claude-activity-${session}.log"
[ -f "$LOG" ] && rm -f "$LOG"

exit 0
