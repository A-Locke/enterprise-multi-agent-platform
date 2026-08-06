<#
.SYNOPSIS
    Packs the source-controlled business data solution (Agent Configuration and
    Conversation Audit Log tables, the Admin/Agent.User/Auditor security roles, and the
    Platform Admin Console model-driven app) and imports it into the current Power Platform
    environment.
.DESCRIPTION
    Milestone 7. The solution was originally built once via the maker portal (no CLI surface
    for authoring new Dataverse schema from scratch) and captured with `pac solution export` +
    `pac solution unpack` -- see ADR-0012. This script is the reproducible half: pack the
    source back into a solution zip and import it, so the whole schema can be recreated on a
    fresh environment without repeating the manual authoring step.

    Requires: `pac auth create` already done against the target Power Platform environment.
#>

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$solutionDir = Join-Path $repoRoot "power-platform\solutions\business-data"
$outputZip = Join-Path $repoRoot "power-platform\solutions\business-data\_build\EnterpriseMultiAgentPlatformBusinessData.zip"

New-Item -ItemType Directory -Force -Path (Split-Path $outputZip) | Out-Null

Write-Host "Packing solution from source..." -ForegroundColor Cyan
pac solution pack --folder $solutionDir --zipfile $outputZip --packagetype Unmanaged
if ($LASTEXITCODE -ne 0) { throw "pac solution pack failed (exit code $LASTEXITCODE)" }

Write-Host "Importing into the current environment..." -ForegroundColor Cyan
pac solution import --path $outputZip --publish-changes
if ($LASTEXITCODE -ne 0) { throw "pac solution import failed (exit code $LASTEXITCODE)" }

Write-Host ""
Write-Host "Done. Tables, security roles, and the Platform Admin Console app are now provisioned." -ForegroundColor Green
