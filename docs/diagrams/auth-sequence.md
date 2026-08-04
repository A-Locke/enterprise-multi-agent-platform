# Sequence Diagram: End-to-End Authentication & Authorization

Covers the Milestone 1 auth demo: a user signs in via the OAuth2 device-code flow and calls
the platform API, which validates the token and enforces role-based authorization.

```mermaid
sequenceDiagram
    actor User
    participant Demo as scripts/demo-auth.ps1
    participant Entra as Microsoft Entra ID
    participant API as Platform API (FastAPI)
    participant JWKS as Entra JWKS endpoint

    User->>Demo: run demo-auth.ps1
    Demo->>Entra: POST /oauth2/v2.0/devicecode
    Entra-->>Demo: device_code + user_code + verification URL
    Demo-->>User: display user_code + URL
    User->>Entra: open URL, enter code, sign in
    Entra-->>Entra: authenticate user, evaluate App Role assignments

    loop poll until approved
        Demo->>Entra: POST /oauth2/v2.0/token (device_code grant)
        Entra-->>Demo: authorization_pending (until user completes sign-in)
    end
    Entra-->>Demo: access_token (aud=api://<client-id>, roles=[...])

    Demo->>API: GET /me (Authorization: Bearer <token>)
    API->>JWKS: fetch signing keys (cached)
    JWKS-->>API: JWKS
    API->>API: validate signature, issuer, audience
    API-->>Demo: 200 {oid, name, roles}

    Demo->>API: GET /admin/ping (Authorization: Bearer <token>)
    API->>API: validate token, check "Admin" in roles claim
    alt Admin role present
        API-->>Demo: 200 {message: "pong", role: "Admin"}
    else Admin role absent
        API-->>Demo: 403 Forbidden
    end
```

## Notes

- Token validation (`apps/api/app/auth.py`) checks signature (against the tenant's JWKS,
  cached after first fetch), issuer, and audience — not just presence of a token.
- Authorization is claim-based (`roles` claim, populated from Entra ID App Role
  assignments) rather than a separate authorization service — appropriate for a single API;
  revisit if/when multiple services need a shared authorization decision point.
- The device-code flow is used here because the demo client is a script, not a browser app.
  A future web frontend (if `/apps/web` is built per the Power Apps evaluation in ADR-0001)
  would use the authorization-code flow with PKCE instead.
