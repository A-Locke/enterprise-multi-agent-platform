<#
.SYNOPSIS
    Milestone 1 end-to-end auth demo: signs in via the OAuth2 device-code flow and
    calls the local API's /me and /admin/ping endpoints to show role-gated access.
.DESCRIPTION
    Requires the API running locally (see apps/api/README.md). Implements the device
    code flow directly via REST calls (no MSAL SDK dependency) per
    https://learn.microsoft.com/entra/identity-platform/v2-oauth2-device-code
#>
param(
    [string]$ApiBaseUrl = "http://127.0.0.1:8000"
)

$ErrorActionPreference = "Stop"

if (-not $env:AZURE_TENANT_ID) {
    . "$PSScriptRoot\load-env.ps1"
}

$tenantId = $env:AZURE_TENANT_ID
$clientId = $env:AZURE_API_APP_CLIENT_ID
$scope = "api://$clientId/access_as_user"

Write-Host "Requesting device code..." -ForegroundColor Cyan
$deviceCodeResponse = Invoke-RestMethod -Method POST `
    -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/devicecode" `
    -Body @{ client_id = $clientId; scope = $scope }

Write-Host ""
Write-Host $deviceCodeResponse.message -ForegroundColor Yellow
Write-Host ""

$interval = $deviceCodeResponse.interval
$expiresAt = (Get-Date).AddSeconds($deviceCodeResponse.expires_in)
$token = $null

while ((Get-Date) -lt $expiresAt) {
    Start-Sleep -Seconds $interval
    try {
        $tokenResponse = Invoke-RestMethod -Method POST `
            -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
            -Body @{
                grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
                client_id   = $clientId
                device_code = $deviceCodeResponse.device_code
            }
        $token = $tokenResponse.access_token
        break
    } catch {
        $errBody = $null
        try { $errBody = $_.ErrorDetails.Message | ConvertFrom-Json } catch {}
        if ($errBody -and $errBody.error -eq "authorization_pending") {
            continue
        } else {
            throw
        }
    }
}

if (-not $token) {
    Write-Error "Timed out waiting for sign-in."
    exit 1
}

Write-Host "Signed in. Calling API..." -ForegroundColor Green

Write-Host ""
Write-Host "GET /me" -ForegroundColor Cyan
Invoke-RestMethod -Uri "$ApiBaseUrl/me" -Headers @{ Authorization = "Bearer $token" } | ConvertTo-Json

Write-Host ""
Write-Host "GET /admin/ping" -ForegroundColor Cyan
try {
    Invoke-RestMethod -Uri "$ApiBaseUrl/admin/ping" -Headers @{ Authorization = "Bearer $token" } | ConvertTo-Json
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    Write-Host "Request failed with HTTP $status (expected 403 if this user lacks the Admin role)." -ForegroundColor Yellow
}
