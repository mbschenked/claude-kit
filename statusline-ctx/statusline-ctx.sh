#!/usr/bin/env bash
# Claude Code status line — single line: cwd | model | ctx: NN%
#
#   ctx: NN%  = percentage of the context window used this session.
#   Color:  green <33%   yellow 33–60%   red >60%
#
# Self-contained: no hooks, no temp files, no background state. The only
# dependency is `jq` (brew install jq / apt install jq).
#
# Claude Code pipes a JSON status payload on stdin; we read three fields and
# print one line. Wire it up in ~/.claude/settings.json as:
#   { "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-ctx.sh" } }
# (install.sh does this for you.)

input=$(cat)

cwd=$(echo "$input"      | jq -r '.workspace.current_dir // .cwd // "?"')
model=$(echo "$input"    | jq -r '.model.display_name // "?"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Collapse $HOME to ~ for a shorter path
home="$HOME"
short_cwd="${cwd/#$home/~}"

# Build the colored ctx segment only when the payload includes a percentage
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

printf "%s | %s%s" "$short_cwd" "$model" "$ctx_segment"
