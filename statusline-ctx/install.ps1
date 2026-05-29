# install.ps1 — install the ctx% status line for Claude Code (Windows).
#
# Idempotent and safe to re-run:
#   1. copies statusline-ctx.ps1 to %USERPROFILE%\.claude\statusline-ctx.ps1
#   2. sets settings.json -> statusLine to call it (backs up settings.json first)
#
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$srcDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$dest      = Join-Path $claudeDir "statusline-ctx.ps1"
$settings  = Join-Path $claudeDir "settings.json"

New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
Copy-Item (Join-Path $srcDir "statusline-ctx.ps1") $dest -Force
Write-Host "  installed $dest"

# Load existing settings (validating JSON) or start fresh
if (Test-Path $settings) {
    try {
        $json = Get-Content $settings -Raw | ConvertFrom-Json
    } catch {
        Write-Error "$settings is not valid JSON - fix or remove it, then re-run."
        exit 1
    }
    Copy-Item $settings "$settings.bak" -Force
} else {
    $json = [PSCustomObject]@{}
}

$statusLine = [PSCustomObject]@{
    type    = "command"
    command = "powershell -NoProfile -File `"$dest`""
}
$json | Add-Member -NotePropertyName statusLine -NotePropertyValue $statusLine -Force

$json | ConvertTo-Json -Depth 20 | Set-Content $settings -Encoding UTF8
Write-Host "  wired statusLine into $settings (backup: $settings.bak)"

Write-Host ""
Write-Host "Done. Restart Claude Code - the status line shows:  cwd | model | ctx: NN%"
