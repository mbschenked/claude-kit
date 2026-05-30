# Claude Code status line (PowerShell) — single line: cwd | model | ctx: NN%
#
#   ctx: NN%  = percentage of the context window used this session.
#   Color:  green <33%   yellow 33-60%   red >60%
#
# The ctx segment is ALWAYS present so it never flickers out. Claude Code
# reports context_window.used_percentage as null early in a session and again
# right after /compact (until the next API response). When that happens we
# recompute the percentage from the token counts, and only if even those are
# missing do we show a dim "ctx: --%" placeholder.
#
# Self-contained: no hooks, no temp files. Uses only built-in ConvertFrom-Json,
# so there are no external dependencies on Windows.
#
# Wire it up in %USERPROFILE%\.claude\settings.json as:
#   { "statusLine": { "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\statusline-ctx.ps1" } }
# (install.ps1 does this for you.)

$ESC = [char]27
$reset = "$ESC[0m"

# Read + parse stdin defensively. A blank/garbled payload on a refresh tick must
# not blank the whole status line, so fall back to an empty object on any error.
$data = $null
try {
    $inputJson = [Console]::In.ReadToEnd()
    if ($inputJson -and $inputJson.Trim().Length -gt 0) {
        $data = $inputJson | ConvertFrom-Json
    }
} catch {
    $data = $null
}

# cwd, with graceful fallbacks
$cwd = "?"
if ($data) {
    if ($data.workspace -and $data.workspace.current_dir) {
        $cwd = $data.workspace.current_dir
    } elseif ($data.cwd) {
        $cwd = $data.cwd
    }
}

$model = "?"
if ($data -and $data.model -and $data.model.display_name) {
    $model = $data.model.display_name
}

# Context percentage. used_percentage is the simplest accurate value, but the
# harness reports it as null early in a session and just after /compact. When
# it's missing, recompute from token counts so the number keeps updating live.
$usedPct = $null
$cw = $null
if ($data) { $cw = $data.context_window }
if ($cw) {
    if ($null -ne $cw.used_percentage) {
        $usedPct = [double]$cw.used_percentage
    } else {
        $size = 200000
        if ($cw.context_window_size) { $size = [double]$cw.context_window_size }

        # total_input_tokens already includes cache reads + writes (input-only,
        # matching how used_percentage is defined). Fall back to summing the
        # current_usage breakdown if the total isn't present.
        $inputTokens = $null
        if ($null -ne $cw.total_input_tokens -and [double]$cw.total_input_tokens -gt 0) {
            $inputTokens = [double]$cw.total_input_tokens
        } elseif ($cw.current_usage) {
            $u = $cw.current_usage
            $sum = 0
            foreach ($f in 'input_tokens','cache_creation_input_tokens','cache_read_input_tokens') {
                if ($null -ne $u.$f) { $sum += [double]$u.$f }
            }
            if ($sum -gt 0) { $inputTokens = $sum }
        }

        if ($null -ne $inputTokens -and $size -gt 0) {
            $usedPct = ($inputTokens / $size) * 100
        }
    }
}

# Collapse home directory to ~
$homePath = $env:USERPROFILE
$shortCwd = $cwd
if ($homePath -and $cwd.StartsWith($homePath)) {
    $shortCwd = "~" + $cwd.Substring($homePath.Length)
}

# ctx segment is always present; dim "--%" placeholder until a value is known.
if ($null -ne $usedPct) {
    $pctInt = [int][Math]::Round($usedPct)
    if ($pctInt -lt 0) { $pctInt = 0 }
    if ($pctInt -gt 100) { $pctInt = 100 }
    if ($pctInt -lt 33) {
        $color = "$ESC[32m"      # green
    } elseif ($pctInt -le 60) {
        $color = "$ESC[33m"      # yellow
    } else {
        $color = "$ESC[31m"      # red
    }
    $ctxSegment = " | ctx: ${color}${pctInt}%${reset}"
} else {
    $ctxSegment = " | ctx: ${ESC}[2m--%${reset}"   # dim: value not reported yet
}

# Single line, no trailing newline
[Console]::Out.Write("$shortCwd | $model$ctxSegment")
