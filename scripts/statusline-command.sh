#!/usr/bin/env bash
# Claude Code status line — shows cwd, model, and context window usage %
# Context thresholds: green <33%, yellow 33-60%, red >60%
#
# Referenced from ~/.claude/settings.json as:
#   { "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" } }
#
# Deployed by scripts/install-mac.sh from ~/ClaudeKit/scripts/statusline-command.sh.
# Don't edit ~/.claude/statusline-command.sh directly — edit this file and re-run install-mac.sh.

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "?"')
model=$(echo "$input" | jq -r '.model.display_name // "?"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Build context segment with color coding if a value is available
if [ -n "$used_pct" ]; then
    # Round to integer
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

printf "%s | %s%s" "$short_cwd" "$model" "$ctx_segment"
