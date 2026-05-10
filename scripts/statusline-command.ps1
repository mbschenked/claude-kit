# Claude Code status line (PowerShell) — shows cwd, model, and context window usage %
# Context thresholds: green <33%, yellow 33-60%, red >60%
#
# Referenced from %USERPROFILE%\.claude\settings.json as:
#   { "statusLine": { "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\statusline-command.ps1" } }
#
# Deployed by scripts\install-win.ps1 from ~\ClaudeKit\scripts\statusline-command.ps1.
# Don't edit the deployed copy directly — edit this file and re-run install-win.ps1.

$inputJson = [Console]::In.ReadToEnd()
$data = $inputJson | ConvertFrom-Json

# Pull fields with graceful fallbacks
$cwd = $null
if ($data.workspace -and $data.workspace.current_dir) {
    $cwd = $data.workspace.current_dir
} elseif ($data.cwd) {
    $cwd = $data.cwd
} else {
    $cwd = "?"
}

$model = "?"
if ($data.model -and $data.model.display_name) {
    $model = $data.model.display_name
}

$usedPct = $null
if ($data.context_window -and $null -ne $data.context_window.used_percentage) {
    $usedPct = $data.context_window.used_percentage
}

# Shorten home directory to ~
$homePath = $env:USERPROFILE
$shortCwd = $cwd
if ($cwd.StartsWith($homePath)) {
    $shortCwd = "~" + $cwd.Substring($homePath.Length)
}

# Build context segment with color coding when a value is available
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

# Single line, no trailing newline (matches Bash printf behavior)
[Console]::Out.Write("$shortCwd | $model$ctxSegment")
