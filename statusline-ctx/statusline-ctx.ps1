# Claude Code status line (PowerShell) — single line: cwd | model | ctx: NN%
#
#   ctx: NN%  = percentage of the context window used this session.
#   Color:  green <33%   yellow 33-60%   red >60%
#
# Self-contained: no hooks, no temp files. Uses only built-in ConvertFrom-Json,
# so there are no external dependencies on Windows.
#
# Wire it up in %USERPROFILE%\.claude\settings.json as:
#   { "statusLine": { "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\statusline-ctx.ps1" } }
# (install.ps1 does this for you.)

$inputJson = [Console]::In.ReadToEnd()
$data = $inputJson | ConvertFrom-Json

# cwd, with graceful fallbacks
$cwd = "?"
if ($data.workspace -and $data.workspace.current_dir) {
    $cwd = $data.workspace.current_dir
} elseif ($data.cwd) {
    $cwd = $data.cwd
}

$model = "?"
if ($data.model -and $data.model.display_name) {
    $model = $data.model.display_name
}

$usedPct = $null
if ($data.context_window -and $null -ne $data.context_window.used_percentage) {
    $usedPct = $data.context_window.used_percentage
}

# Collapse home directory to ~
$homePath = $env:USERPROFILE
$shortCwd = $cwd
if ($cwd.StartsWith($homePath)) {
    $shortCwd = "~" + $cwd.Substring($homePath.Length)
}

# Colored ctx segment when a percentage is present
$ESC = [char]27
$reset = "$ESC[0m"
$ctxSegment = ""

if ($null -ne $usedPct) {
    $pctInt = [int][Math]::Round([double]$usedPct)
    if ($pctInt -lt 33) {
        $color = "$ESC[32m"      # green
    } elseif ($pctInt -le 60) {
        $color = "$ESC[33m"      # yellow
    } else {
        $color = "$ESC[31m"      # red
    }
    $ctxSegment = " | ctx: ${color}${pctInt}%${reset}"
}

# Single line, no trailing newline
[Console]::Out.Write("$shortCwd | $model$ctxSegment")
