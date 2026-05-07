# install-win.ps1 — copy this kit's agents and commands into %USERPROFILE%\.claude\
# Idempotent: safe to re-run after a `git pull`.
#
# Usage: .\install-win.ps1 [-Prune]
#   -Prune  remove .md files in %USERPROFILE%\.claude\{agents,commands}\ that aren't in this repo

param(
    [switch]$Prune
)

$ErrorActionPreference = "Stop"

$RepoDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Install-Subdir {
    param([string]$Subdir)

    $SrcDir = Join-Path $RepoDir $Subdir
    $Dest = Join-Path $env:USERPROFILE ".claude\$Subdir"

    if (-not (Test-Path $SrcDir)) {
        return
    }

    if (-not (Test-Path $Dest)) {
        New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    }

    $RepoFiles = Get-ChildItem -Path $SrcDir -Filter "*.md"
    $RepoNames = @($RepoFiles | ForEach-Object { $_.Name })

    $count = 0
    $RepoFiles | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination (Join-Path $Dest $_.Name) -Force
        Write-Host "  installed $Subdir/$($_.Name)"
        $count++
    }

    $pruned = 0
    if ($Prune) {
        Get-ChildItem -Path $Dest -Filter "*.md" | ForEach-Object {
            if ($RepoNames -notcontains $_.Name) {
                Remove-Item -Path $_.FullName -Force
                Write-Host "  pruned $Subdir/$($_.Name)"
                $pruned++
            }
        }
    }

    Write-Host "Installed $count $Subdir file(s) to $Dest"
    if ($Prune) {
        Write-Host "Pruned $pruned stale $Subdir file(s)"
    }
}

Install-Subdir -Subdir "agents"
Write-Host ""
Install-Subdir -Subdir "commands"

Write-Host ""
Write-Host "Restart Claude Code if it was already running."
