<#
.SYNOPSIS
    Generates the real (gitignored) connector definition files from the committed
    templates and creates the custom connector in Dataverse via `pac connector create`.
.DESCRIPTION
    Milestone 3 prep. Templates in power-platform/solutions/connectors/platform-api/
    use placeholders (<AZURE_API_APP_CLIENT_ID>, <APIM_HOSTNAME>, etc.) instead of real
    values, consistent with the rest of the repo's real-values-only-in-.env discipline.
    This script substitutes real values from .env / azd env and writes the generated
    files next to the templates (gitignored), then calls `pac connector create`.

    Requires: .env loaded (scripts/load-env.ps1), `pac auth create` already done against
    the Power Platform environment, and `azd env get-values` reachable (for the APIM
    gateway hostname).
#>

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$connectorDir = Join-Path $repoRoot "power-platform\solutions\connectors\platform-api"

if (-not $env:AZURE_TENANT_ID) {
    . "$PSScriptRoot\load-env.ps1"
}

Write-Host "Fetching APIM gateway hostname from azd..." -ForegroundColor Cyan
Push-Location $repoRoot
$apimGatewayUrl = (azd env get-values --output json | ConvertFrom-Json).APIM_GATEWAY_URL
Pop-Location
if (-not $apimGatewayUrl) {
    throw "Could not read APIM_GATEWAY_URL from azd env. Has 'azd provision' run in this environment?"
}
$apimHostname = ($apimGatewayUrl -replace '^https?://', '') -replace '/$', ''

Write-Host "Generating apiDefinition.json and apiProperties.json..." -ForegroundColor Cyan
$apiDefinition = Get-Content (Join-Path $connectorDir "apiDefinition.template.json") -Raw
$apiDefinition = $apiDefinition -replace '<APIM_HOSTNAME>', $apimHostname
Set-Content -Path (Join-Path $connectorDir "apiDefinition.json") -Value $apiDefinition -Encoding ASCII

$apiProperties = Get-Content (Join-Path $connectorDir "apiProperties.template.json") -Raw
$apiProperties = $apiProperties -replace '<AZURE_API_APP_CLIENT_ID>', $env:AZURE_API_APP_CLIENT_ID
$apiProperties = $apiProperties -replace '<AZURE_TENANT_ID>', $env:AZURE_TENANT_ID
Set-Content -Path (Join-Path $connectorDir "apiProperties.json") -Value $apiProperties -Encoding ASCII

Write-Host "Creating the connector via pac connector create..." -ForegroundColor Cyan
Push-Location $connectorDir
pac connector create --settings-file "settings.json"
Pop-Location

Write-Host ""
Write-Host "Done. Next (manual, portal-only):" -ForegroundColor Green
Write-Host "1. In admin.powerplatform.microsoft.com / make.powerapps.com, open the new connector's Security tab."
Write-Host "2. Switch Identity Provider to Azure Active Directory, then select the managed identity option (not client secret)."
Write-Host "3. Save, then copy the connector's Redirect URL, issuer, and subject identifier from the details page."
Write-Host "4. Send those three values back so the redirect URI and federated credential can be added to the Entra app registration."
