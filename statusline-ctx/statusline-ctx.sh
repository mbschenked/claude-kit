#!/usr/bin/env bash
# Claude Code status line — single line: cwd | model | ctx: NN%
#
#   ctx: NN%  = percentage of the context window used this session.
#   Color:  green <33%   yellow 33–60%   red >60%
#
# The ctx segment is ALWAYS present so it never flickers out. Claude Code
# reports context_window.used_percentage as null early in a session and again
# right after /compact (until the next API response). When that happens we
# recompute the percentage from the token counts, and only if even those are
# missing do we show a dim "ctx: --%" placeholder.
#
# Self-contained: no hooks, no temp files, no background state. The only
# dependency is `jq` (brew install jq / apt install jq).
#
# Wire it up in ~/.claude/settings.json as:
#   { "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-ctx.sh" } }
# (install.sh does this for you.)

input=$(cat)

# Parse defensively. On empty or garbled stdin jq emits nothing, so cwd/model
# fall back to "?" and pct stays empty (rendered as the dim --% placeholder).
# A single code path keeps the line — and the ctx segment — always present.
cwd=$(echo "$input"   | jq -r '.workspace.current_dir // .cwd // "?"' 2>/dev/null)
model=$(echo "$input" | jq -r '.model.display_name // "?"' 2>/dev/null)
cwd="${cwd:-?}"
model="${model:-?}"

# Prefer used_percentage; recompute from token counts when the harness reports
# it null (early in a session, or just after /compact). total_input_tokens
# already includes cache reads + writes, matching used_percentage's definition;
# treat a 0 total as "not yet reported" and fall through to current_usage.
pct=$(echo "$input" | jq -r '
  if (.context_window.used_percentage // null) != null then
    .context_window.used_percentage
  else
    (.context_window.context_window_size // 200000) as $size
    | ( if (.context_window.total_input_tokens // 0) > 0
        then .context_window.total_input_tokens
        else ( (.context_window.current_usage.input_tokens // 0)
             + (.context_window.current_usage.cache_creation_input_tokens // 0)
             + (.context_window.current_usage.cache_read_input_tokens // 0) )
        end ) as $in
    | if ($in > 0 and $size > 0) then ($in / $size * 100) else empty end
  end
' 2>/dev/null)

# Collapse $HOME to ~ for a shorter path
home="$HOME"
short_cwd="${cwd/#$home/~}"

reset="\033[0m"
if [ -n "$pct" ]; then
    pct_int=$(printf '%.0f' "$pct")
    [ "$pct_int" -lt 0 ]   && pct_int=0
    [ "$pct_int" -gt 100 ] && pct_int=100
    if [ "$pct_int" -lt 33 ]; then
        color="\033[32m"   # green
    elif [ "$pct_int" -le 60 ]; then
        color="\033[33m"   # yellow
    else
        color="\033[31m"   # red
    fi
    ctx_segment=$(printf " | ctx: ${color}%d%%${reset}" "$pct_int")
else
    ctx_segment=$(printf " | ctx: \033[2m--%%${reset}")   # dim: not reported yet
fi

printf "%s | %s%s" "$short_cwd" "$model" "$ctx_segment"
