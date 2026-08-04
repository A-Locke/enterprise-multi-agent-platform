<#
.SYNOPSIS
    Creates (or reuses) the Entra ID app registration protecting the platform API,
    with App Roles (Admin / Agent.User / Auditor) and a delegated API scope.
.DESCRIPTION
    Idempotent: re-running finds the existing registration by display name instead
    of failing. Optionally assigns roles to users for the Milestone 1 end-to-end
    auth demo. Requires `az login` first.
.PARAMETER AssignAdminTo
    UPNs to assign the Admin app role to.
.PARAMETER AssignAgentUserTo
    UPNs to assign the Agent.User app role to.
#>
param(
    [string]$DisplayName = "Enterprise Multi-Agent Platform API",
    [string[]]$AssignAdminTo = @(),
    [string[]]$AssignAgentUserTo = @()
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

Write-Host "Checking for existing app registration '$DisplayName'..." -ForegroundColor Cyan
$existingAppId = az ad app list --display-name $DisplayName --query "[0].appId" -o tsv

if ($existingAppId) {
    Write-Host "Found existing app registration: $existingAppId" -ForegroundColor Yellow
    $appId = $existingAppId
} else {
    Write-Host "Creating app registration..." -ForegroundColor Cyan
    $appId = az ad app create `
        --display-name $DisplayName `
        --sign-in-audience AzureADMyOrg `
        --app-roles "@$repoRoot\infra\entra\app-roles.json" `
        --query appId -o tsv
    Write-Host "Created app registration: $appId" -ForegroundColor Green

    Write-Host "Setting identifier URI and exposing API scope..." -ForegroundColor Cyan
    az ad app update --id $appId --identifier-uris "api://$appId" | Out-Null
    az ad app update --id $appId --set api="@$repoRoot\infra\entra\api-scope.json" | Out-Null
}

# Allows the MSAL device-code flow (scripts/demo-auth.ps1) to work without a client
# secret -- device code is a "public client" flow.
Write-Host "Enabling public client flows (needed for MSAL device-code demo)..." -ForegroundColor Cyan
az ad app update --id $appId --set isFallbackPublicClient=true | Out-Null

Write-Host "Ensuring service principal exists..." -ForegroundColor Cyan
$spId = az ad sp list --filter "appId eq '$appId'" --query "[0].id" -o tsv
if (-not $spId) {
    $spId = az ad sp create --id $appId --query id -o tsv
    Write-Host "Created service principal: $spId" -ForegroundColor Green
} else {
    Write-Host "Service principal already exists: $spId" -ForegroundColor Yellow
}

$roles = Get-Content "$repoRoot\infra\entra\app-roles.json" | ConvertFrom-Json
$adminRoleId = ($roles | Where-Object { $_.value -eq "Admin" }).id
$agentUserRoleId = ($roles | Where-Object { $_.value -eq "Agent.User" }).id

$assignments = @()
foreach ($upn in $AssignAdminTo) { $assignments += [pscustomobject]@{ Upn = $upn; RoleId = $adminRoleId; RoleName = "Admin" } }
foreach ($upn in $AssignAgentUserTo) { $assignments += [pscustomobject]@{ Upn = $upn; RoleId = $agentUserRoleId; RoleName = "Agent.User" } }

foreach ($a in $assignments) {
    Write-Host "Assigning $($a.RoleName) role to $($a.Upn)..." -ForegroundColor Cyan
    $userId = az ad user show --id $a.Upn --query id -o tsv

    $existing = az rest --method GET --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$spId/appRoleAssignedTo" | ConvertFrom-Json
    $alreadyAssigned = $existing.value | Where-Object { $_.principalId -eq $userId -and $_.appRoleId -eq $a.RoleId }
    if ($alreadyAssigned) {
        Write-Host "Already assigned - skipping." -ForegroundColor Yellow
        continue
    }

    $bodyFile = Join-Path $env:TEMP "approle-assignment-body.json"
    $json = @{ principalId = $userId; resourceId = $spId; appRoleId = $a.RoleId } | ConvertTo-Json -Compress
    Set-Content -Path $bodyFile -Value $json -Encoding ASCII

    az rest --method POST `
        --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$spId/appRoleAssignedTo" `
        --body "@$bodyFile" `
        --headers "Content-Type=application/json"
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Assignment for $($a.Upn) ($($a.RoleName)) failed - see error above."
    } else {
        Write-Host "Assigned." -ForegroundColor Green
    }
}

$tenantId = az account show --query tenantId -o tsv

Write-Host ""
Write-Host "App (client) ID: $appId" -ForegroundColor Green
Write-Host "Tenant ID: $tenantId" -ForegroundColor Green
Write-Host "Add these to .env as AZURE_API_APP_CLIENT_ID / AZURE_TENANT_ID (tenant ID already present)." -ForegroundColor Yellow
Write-Host "Remember: an Entra admin must grant admin consent for the exposed scope (manual-setup.md #4)." -ForegroundColor Yellow
