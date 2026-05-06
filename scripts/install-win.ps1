# install-win.ps1 — copy this kit's agents into %USERPROFILE%\.claude\agents
# Idempotent: safe to re-run after a `git pull`.
#
# Usage: .\install-win.ps1 [-Prune]
#   -Prune  remove .md files in %USERPROFILE%\.claude\agents that aren't in this repo

param(
    [switch]$Prune
)

$ErrorActionPreference = "Stop"

$RepoDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Dest = Join-Path $env:USERPROFILE ".claude\agents"

if (-not (Test-Path $Dest)) {
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
}

$RepoAgentsDir = Join-Path $RepoDir "agents"
$RepoAgents = Get-ChildItem -Path $RepoAgentsDir -Filter "*.md"
$RepoNames = @($RepoAgents | ForEach-Object { $_.Name })

$count = 0
$RepoAgents | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination (Join-Path $Dest $_.Name) -Force
    Write-Host "  installed $($_.Name)"
    $count++
}

$pruned = 0
if ($Prune) {
    Get-ChildItem -Path $Dest -Filter "*.md" | ForEach-Object {
        if ($RepoNames -notcontains $_.Name) {
            Remove-Item -Path $_.FullName -Force
            Write-Host "  pruned $($_.Name)"
            $pruned++
        }
    }
}

Write-Host ""
Write-Host "Installed $count agent(s) to $Dest"
if ($Prune) {
    Write-Host "Pruned $pruned stale agent(s)"
}
Write-Host "Restart Claude Code if it was already running."
