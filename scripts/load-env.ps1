<#
.SYNOPSIS
    Loads .env into the current PowerShell session's environment variables.
.DESCRIPTION
    PowerShell has no native `.env` sourcing. Run this (dot-sourced) before az/azd/pac
    commands so ${VAR} references in infra/main.parameters.json resolve correctly:
        . .\scripts\load-env.ps1
#>

$envFile = Join-Path $PSScriptRoot "..\.env"

if (-not (Test-Path $envFile)) {
    Write-Warning ".env not found at $envFile — copy .env.example to .env and fill in real values first."
    return
}

Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
        $key, $value = $line.Split("=", 2)
        $key = $key.Trim()
        $value = $value.Trim()
        if ($value) {
            Set-Item -Path "Env:$key" -Value $value
        }
    }
}

Write-Host "Loaded .env into the current session." -ForegroundColor Green

# Self-install the pre-commit hook that blocks committing real .env values
# (see CLAUDE.md) -- idempotent, safe to run every time.
$repoRoot = Join-Path $PSScriptRoot ".."
git -C $repoRoot config core.hooksPath .githooks

