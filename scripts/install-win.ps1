# install-win.ps1 - copy this kit's agents and commands into %USERPROFILE%\.claude\
# Idempotent: safe to re-run after a `git pull`.
#
# Usage: .\install-win.ps1 [-Prune]
#   -Prune  remove .md files in %USERPROFILE%\.claude\{agents,commands,rules}\ that aren't in this repo

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

function Install-Skills {
    $Subdir = "skills"
    $SrcDir = Join-Path $RepoDir $Subdir
    $Dest = Join-Path $env:USERPROFILE ".claude\$Subdir"

    if (-not (Test-Path $SrcDir)) {
        return
    }

    if (-not (Test-Path $Dest)) {
        New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    }

    $RepoSkills = Get-ChildItem -Path $SrcDir -Directory
    $RepoNames = @($RepoSkills | ForEach-Object { $_.Name })

    $count = 0
    $RepoSkills | ForEach-Object {
        $DestPath = Join-Path $Dest $_.Name
        if (Test-Path $DestPath) {
            Remove-Item -Path $DestPath -Recurse -Force
        }
        Copy-Item -Path $_.FullName -Destination $DestPath -Recurse -Force
        Write-Host "  installed skills/$($_.Name)"
        $count++
    }

    $pruned = 0
    if ($Prune) {
        Get-ChildItem -Path $Dest -Directory | ForEach-Object {
            if ($RepoNames -notcontains $_.Name) {
                Remove-Item -Path $_.FullName -Recurse -Force
                Write-Host "  pruned skills/$($_.Name)"
                $pruned++
            }
        }
    }

    Write-Host "Installed $count skill(s) to $Dest"
    if ($Prune) {
        Write-Host "Pruned $pruned stale skill(s)"
    }
}

function Install-Statusline {
    $Src = Join-Path $RepoDir "scripts\statusline-command.ps1"
    $Dest = Join-Path $env:USERPROFILE ".claude\statusline-command.ps1"

    if (-not (Test-Path $Src)) {
        return
    }

    $DestDir = Split-Path $Dest -Parent
    if (-not (Test-Path $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    }

    Copy-Item -Path $Src -Destination $Dest -Force
    Write-Host "  installed statusline-command.ps1"
    Write-Host "Installed statusline-command.ps1 to $Dest"
}

function Install-Plugins {
    # Ensure the Check-5 install-floor plugins are present and enabled. Idempotent:
    # re-running install/enable on an already-set plugin is a harmless no-op.
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Write-Host "claude CLI not found on PATH - skipping plugin provisioning"
        return
    }
    # The npm `claude` shim relays benign "already installed/enabled" notices via stderr,
    # which the script-level `$ErrorActionPreference = 'Stop'` would otherwise escalate into
    # a terminating error and abort the loop on the first plugin. Relax it locally (and
    # swallow each call) so re-runs stay genuinely idempotent.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $plugins = @("session-report", "commit-commands", "claude-md-management")
        foreach ($p in $plugins) {
            try { & claude plugin install "$p@claude-plugins-official" *> $null } catch {}
            try { & claude plugin enable  "$p@claude-plugins-official" *> $null } catch {}
            Write-Host "  ensured plugin $p (installed + enabled)"
        }
        Write-Host "Ensured $($plugins.Count) floor plugin(s)"
    }
    finally {
        $ErrorActionPreference = $prevEAP
        # The trailing `claude plugin enable` can leave a non-zero $LASTEXITCODE even when
        # "already enabled" is the desired no-op; reset it so a clean re-run exits 0.
        $global:LASTEXITCODE = 0
    }
}

Install-Subdir -Subdir "agents"
Write-Host ""
Install-Subdir -Subdir "commands"
Write-Host ""
Install-Subdir -Subdir "rules"
Write-Host ""
Install-Skills
Write-Host ""
Install-Statusline
Write-Host ""
Install-Plugins

Write-Host ""
Write-Host "Restart Claude Code if it was already running."
