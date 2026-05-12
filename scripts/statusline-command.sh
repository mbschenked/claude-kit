#!/usr/bin/env bash
# Claude Code status line
#   Line 1: cwd | model | ctx %
#   Line 2+: live activity board (in-flight tools/subagents + recent completions)
#
# Context thresholds: green <33%, yellow 33-60%, red >60%
# Activity board reads /tmp/claude-activity-${session}.log, populated by the
# log-activity.sh PreToolUse/PostToolUse hook. Requires refreshInterval >= 1
# in settings.json for live updates during long tool calls.
#
# Referenced from ~/.claude/settings.json as:
#   { "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh", "refreshInterval": 1 } }
#
# Deployed by scripts/install-mac.sh from ~/ClaudeKit/scripts/statusline-command.sh.
# Don't edit ~/.claude/statusline-command.sh directly — edit this file and re-run install-mac.sh.

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "?"')
model=$(echo "$input" | jq -r '.model.display_name // "?"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
session=$(echo "$input" | jq -r '.session_id // "unknown"')

home="$HOME"
short_cwd="${cwd/#$home/~}"

# --- Line 1: cwd | model | ctx % ---
if [ -n "$used_pct" ]; then
    pct_int=$(printf '%.0f' "$used_pct")
    if [ "$pct_int" -lt 33 ]; then
        color="\033[32m"   # green
    elif [ "$pct_int" -le 60 ]; then
        color="\033[33m"   # yellow
    else
        color="\033[31m"   # red
    fi
    reset="\033[0m"
    ctx_segment=$(printf " | ctx: ${color}%d%%${reset}" "$pct_int")
else
    ctx_segment=""
fi

line1=$(printf "%s | %s%s" "$short_cwd" "$model" "$ctx_segment")

# --- Lines 2+: activity board ---
LOG="/tmp/claude-activity-${session}.log"
activity=""
if [ -s "$LOG" ]; then
    now=$(python3 -c 'import time; print(time.time())')
    spinner_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    frame_idx=$(( $(date +%s) % 10 ))
    spin="${spinner_chars[$frame_idx]}"

    activity=$(jq -rs \
        --arg now "$now" \
        --arg spin "$spin" '
        reduce .[] as $e ({};
          if $e.kind == "start" then
            .[$e.id] = {label: $e.label, start: $e.ts, end: null}
          elif .[$e.id] != null then
            .[$e.id].end = $e.ts
          else
            .
          end
        )
        | to_entries
        | map(.value + {id: .key})
        | map(select((.end == null) or ((($now|tonumber) - .end) < 3)))
        | sort_by(.start)
        | .[0:5]
        | map(
            if .end == null then
              "  [36m\($spin)[0m \(.label) [90m(\((($now|tonumber) - .start)|floor)s)[0m"
            else
              "  [32m✓[0m \(.label) [90m(\(((.end - .start) * 10 | floor) / 10)s)[0m"
            end
          )
        | join("\n")
    ' "$LOG" 2>/dev/null || true)
fi

if [ -n "$activity" ]; then
    printf "%s\n%s" "$line1" "$activity"
else
    printf "%s" "$line1"
fi
