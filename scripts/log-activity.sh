#!/usr/bin/env bash
# log-activity.sh — Claude Code PreToolUse/PostToolUse hook
#
# Appends one JSON event per tool invocation to /tmp/claude-activity-${session}.log.
# Filters to slow / long-running tools so the statusLine activity board stays clean.
# Per-session log file so a crashed session can't leave phantom rows in the next one.
#
# Deployed by scripts/install-mac.sh to ~/.claude/scripts/log-activity.sh.
# Don't edit ~/.claude/scripts/log-activity.sh directly — edit this file and re-run install-mac.sh.

set -uo pipefail

input=$(cat)

event=$(jq -r '.hook_event_name // ""' <<<"$input")
tool=$(jq -r '.tool_name // ""' <<<"$input")
id=$(jq -r '.tool_use_id // empty' <<<"$input")
session=$(jq -r '.session_id // "unknown"' <<<"$input")

# Slow tools only
case "$tool" in
  Agent|Bash|WebFetch|WebSearch|mcp__*) ;;
  *) exit 0 ;;
esac

# Per-tool human label
label=""
case "$tool" in
  Agent)
    sub=$(jq -r '.tool_input.subagent_type // "subagent"' <<<"$input")
    label="Agent: $sub"
    ;;
  Bash)
    cmd=$(jq -r '.tool_input.command // ""' <<<"$input" | tr '\n' ' ' | head -c 50)
    label="Bash: $cmd"
    ;;
  WebFetch)
    url=$(jq -r '.tool_input.url // ""' <<<"$input")
    host=$(echo "$url" | sed -E 's|^https?://||; s|/.*||')
    label="WebFetch: $host"
    ;;
  WebSearch)
    q=$(jq -r '.tool_input.query // ""' <<<"$input" | head -c 40)
    label="WebSearch: $q"
    ;;
  mcp__*)
    label="$tool"
    ;;
esac

case "$event" in
  PreToolUse) kind="start" ;;
  PostToolUse) kind="end" ;;
  *) exit 0 ;;
esac

# Fallback id if tool_use_id is missing (shouldn't happen per docs)
if [ -z "$id" ]; then
  id="$tool-$(date +%s%N)"
fi

LOG="/tmp/claude-activity-${session}.log"
ts=$(python3 -c 'import time; print(time.time())')

jq -nc \
  --arg ts "$ts" \
  --arg kind "$kind" \
  --arg id "$id" \
  --arg label "$label" \
  '{ts: ($ts|tonumber), kind: $kind, id: $id, label: $label}' \
  >> "$LOG"

# Cap log size — keep last 200 lines once it exceeds 500
lines=$(wc -l < "$LOG" 2>/dev/null || echo 0)
if [ "$lines" -gt 500 ]; then
  tail -n 200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

exit 0
