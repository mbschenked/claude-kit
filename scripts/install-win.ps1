# install-win.ps1 — copy this kit's agents into %USERPROFILE%\.claude\agents
# Idempotent: safe to re-run after a `git pull`.

$ErrorActionPreference = "Stop"

$RepoDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Dest = Join-Path $env:USERPROFILE ".claude\agents"

if (-not (Test-Path $Dest)) {
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
}

$count = 0
Get-ChildItem -Path (Join-Path $RepoDir "agents") -Filter "*.md" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination (Join-Path $Dest $_.Name) -Force
    Write-Host "  installed $($_.Name)"
    $count++
}

Write-Host ""
Write-Host "Installed $count agent(s) to $Dest"
Write-Host "Restart Claude Code if it was already running."
