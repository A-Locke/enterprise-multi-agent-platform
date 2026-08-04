<#
.SYNOPSIS
    Auth + agent demo: signs in via the OAuth2 device-code flow, then calls /me,
    /admin/ping, and /agent/chat to show role-gated access and the Semantic Kernel agent.
.DESCRIPTION
    Requires the API running locally (see apps/api/README.md) or point -ApiBaseUrl at the
    APIM gateway / Container App FQDN for the deployed version. Implements the device code
    flow directly via REST calls (no MSAL SDK dependency) per
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

# Debug: decode the token payload (unverified, local-only) to see what Entra actually issued.
$payloadB64 = $token.Split(".")[1]
$payloadB64 = $payloadB64.Replace("-", "+").Replace("_", "/")
switch ($payloadB64.Length % 4) { 2 { $payloadB64 += "==" } 3 { $payloadB64 += "=" } }
$claims = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payloadB64)) | ConvertFrom-Json
Write-Host ""
Write-Host "DEBUG token claims: aud=$($claims.aud) iss=$($claims.iss) roles=$($claims.roles -join ',') scp=$($claims.scp)" -ForegroundColor DarkGray

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

Write-Host ""
Write-Host "POST /agent/chat" -ForegroundColor Cyan
try {
    $body = @{ message = "In one sentence, what are you?" } | ConvertTo-Json
    Invoke-RestMethod -Method POST -Uri "$ApiBaseUrl/agent/chat" `
        -Headers @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" } `
        -Body $body | ConvertTo-Json
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    Write-Host "Request failed with HTTP $status (expected 403 if this user lacks Admin/Agent.User)." -ForegroundColor Yellow
}
