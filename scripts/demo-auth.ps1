<#
.SYNOPSIS
    Auth + agent demo: signs in via the OAuth2 authorization-code + PKCE flow, then calls
    /me, /admin/ping, and /agent/chat to show role-gated access and the Semantic Kernel agent.
.DESCRIPTION
    Requires the API running locally (see apps/api/README.md) or point -ApiBaseUrl at the
    APIM gateway / Container App FQDN for the deployed version. Implements auth-code + PKCE
    directly via REST calls (no MSAL SDK dependency) -- a local HttpListener catches the
    browser redirect, per https://learn.microsoft.com/entra/identity-platform/v2-oauth2-auth-code-flow

    Originally used the device-code flow, but this tenant's Security Defaults policy blocks
    it outright (AADSTS530035: BlockedBySecurityDefaults -- device code is a common phishing
    vector, so Security Defaults treats it as unsafe regardless of app role assignment or
    consent). Auth-code + PKCE is the modern, non-legacy interactive flow Security Defaults
    doesn't block, and is the more correct choice for a real public client anyway -- see
    docs/security-model.md.
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
# Must exactly match a URI registered under this app's "publicClient.redirectUris" in Entra.
$redirectUri = "http://localhost:8400/callback/"

function New-CodeVerifier {
    $bytes = New-Object byte[] 64
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Get-CodeChallenge([string]$verifier) {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hash = $sha256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($verifier))
    [Convert]::ToBase64String($hash).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Get-QueryParams([string]$query) {
    $params = @{}
    $query.TrimStart('?').Split('&') | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $params[$matches[1]] = [System.Uri]::UnescapeDataString($matches[2])
        }
    }
    return $params
}

$state = [Guid]::NewGuid().ToString("N")
$codeVerifier = New-CodeVerifier
$codeChallenge = Get-CodeChallenge $codeVerifier

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($redirectUri)
$listener.Start()

$authorizeUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize" +
    "?client_id=$clientId" +
    "&response_type=code" +
    "&redirect_uri=$([uri]::EscapeDataString($redirectUri))" +
    "&response_mode=query" +
    "&scope=$([uri]::EscapeDataString($scope))" +
    "&code_challenge=$codeChallenge" +
    "&code_challenge_method=S256" +
    "&state=$state"

Write-Host "Opening browser for sign-in..." -ForegroundColor Cyan
Start-Process $authorizeUrl

Write-Host "Waiting for redirect on $redirectUri ..." -ForegroundColor Cyan
$context = $listener.GetContext()  # blocks until the browser redirects back
$queryParams = Get-QueryParams $context.Request.Url.Query

$responseHtml = "<html><body><h2>Signed in - you can close this tab.</h2></body></html>"
$buffer = [System.Text.Encoding]::UTF8.GetBytes($responseHtml)
$context.Response.ContentLength64 = $buffer.Length
$context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
$context.Response.OutputStream.Close()
$listener.Stop()

if ($queryParams["error"]) {
    Write-Error "Sign-in failed: $($queryParams['error']) - $($queryParams['error_description'])"
    exit 1
}
if ($queryParams["state"] -ne $state) {
    Write-Error "State mismatch on redirect - possible CSRF, aborting."
    exit 1
}

Write-Host "Got authorization code. Exchanging for token..." -ForegroundColor Cyan
$tokenResponse = Invoke-RestMethod -Method POST `
    -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
    -Body @{
        grant_type    = "authorization_code"
        client_id     = $clientId
        code          = $queryParams["code"]
        redirect_uri  = $redirectUri
        code_verifier = $codeVerifier
    }
$token = $tokenResponse.access_token

if (-not $token) {
    Write-Error "Token exchange did not return an access token."
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
