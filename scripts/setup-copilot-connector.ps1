<#
.SYNOPSIS
    Generates the real (gitignored) connector definition files from the committed
    templates and creates or updates the custom connector in Dataverse.
.DESCRIPTION
    Milestone 3 prep. Templates in power-platform/solutions/connectors/platform-api/
    (*.template.json) use placeholders (<AZURE_API_APP_CLIENT_ID>, <APIM_HOSTNAME>, etc.)
    instead of real values, consistent with the rest of the repo's real-values-only-in-.env
    discipline. This script substitutes real values from .env / azd env and writes the
    generated files (gitignored) next to the templates, then calls `pac connector
    create`/`update` -- idempotent: re-running finds the existing connector by name and
    updates it instead of failing.

    Requires: .env loaded (scripts/load-env.ps1), `pac auth create` + `pac org select`
    already done against the Power Platform environment, and `azd env get-values`
    reachable (for the APIM gateway hostname).
#>

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$connectorDir = Join-Path $repoRoot "power-platform\solutions\connectors\platform-api"

if (-not $env:AZURE_TENANT_ID) {
    . "$PSScriptRoot\load-env.ps1"
}

Write-Host "Checking for an existing connector..." -ForegroundColor Cyan
$existingLine = pac connector list | Select-String "Multi-Agent Platform API"
$connectorId = if ($existingLine) { ($existingLine -split '\s+')[0] } else { $null }
if ($connectorId) {
    Write-Host "Found existing connector $connectorId - will update." -ForegroundColor Yellow
} else {
    Write-Host "No existing connector found - will create." -ForegroundColor Yellow
}

Write-Host "Fetching APIM gateway hostname from azd..." -ForegroundColor Cyan
Push-Location $repoRoot
$apimGatewayUrl = (azd env get-values --output json | ConvertFrom-Json).APIM_GATEWAY_URL
Pop-Location
if (-not $apimGatewayUrl) {
    throw "Could not read APIM_GATEWAY_URL from azd env. Has 'azd provision' run in this environment?"
}
$apimHostname = ($apimGatewayUrl -replace '^https?://', '') -replace '/$', ''

Write-Host "Generating apiDefinition.json, apiProperties.json, settings.json..." -ForegroundColor Cyan

$apiDefinition = Get-Content (Join-Path $connectorDir "apiDefinition.template.json") -Raw
$apiDefinition = $apiDefinition -replace '<APIM_HOSTNAME>', $apimHostname
Set-Content -Path (Join-Path $connectorDir "apiDefinition.json") -Value $apiDefinition -Encoding ASCII

$apiProperties = Get-Content (Join-Path $connectorDir "apiProperties.template.json") -Raw
$apiProperties = $apiProperties -replace '<AZURE_API_APP_CLIENT_ID>', $env:AZURE_API_APP_CLIENT_ID
$apiProperties = $apiProperties -replace '<AZURE_TENANT_ID>', $env:AZURE_TENANT_ID
Set-Content -Path (Join-Path $connectorDir "apiProperties.json") -Value $apiProperties -Encoding ASCII

$settings = Get-Content (Join-Path $connectorDir "settings.template.json") -Raw
$connectorIdJson = if ($connectorId) { "`"$connectorId`"" } else { "null" }
$settings = $settings -replace '"<CONNECTOR_ID_OR_NULL>"', $connectorIdJson
Set-Content -Path (Join-Path $connectorDir "settings.json") -Value $settings -Encoding ASCII

Push-Location $connectorDir
if ($connectorId) {
    Write-Host "Updating the connector via pac connector update..." -ForegroundColor Cyan
    pac connector update --settings-file "settings.json"
} else {
    Write-Host "Creating the connector via pac connector create..." -ForegroundColor Cyan
    pac connector create --settings-file "settings.json"
}
Pop-Location

Write-Host ""
Write-Host "Done. Next (manual, portal-only):" -ForegroundColor Green
Write-Host "1. In admin.powerplatform.microsoft.com / make.powerapps.com, open the connector's Security tab."
Write-Host "2. Switch Identity Provider to Azure Active Directory, then select the managed identity option (not client secret)."
Write-Host "3. Save, then copy the connector's Redirect URL, issuer, and subject identifier from the details page."
Write-Host "4. Send those three values back so the redirect URI and federated credential can be added to the Entra app registration."
