# Security Model

Living document — grows with each milestone. Current state reflects Milestone 2
(Core Orchestration); items marked *planned* land in later milestones.

## Identity

Single Microsoft Entra ID tenant hosts both Azure resources and Power Platform/Dataverse
(ADR-0004) — no cross-tenant identity federation needed for this project's scope.

Two categories of principal exist today:
- **Human users**, authenticating interactively (device-code flow today; authorization-code
  + PKCE for any future browser client).
- **Workload identities**: the API's Container App uses a **system-assigned managed
  identity** for both of its Azure dependencies — `AcrPull` on the Container Registry (image
  pulls) and `Cognitive Services OpenAI User` on the Azure OpenAI resource (chat completions).
  Locally, the same code path authenticates via the developer's own `az login` session
  (`DefaultAzureCredential`'s fallback chain) — no separate cloud/local auth branches to
  maintain, and no API keys anywhere: the OpenAI resource has `disableLocalAuth: true`, so
  key-based auth isn't even a configuration option that exists to misuse.

Almost no client secrets exist anywhere in this project's Entra app registrations — the API's
registration (`infra/entra/`) is a public client for its own device-code / PKCE flows, and
service-to-service Azure calls use managed identity, which requires no stored credential at
all. The one accepted exception is the Copilot Studio custom connector's OAuth delegated
auth: the zero-secret managed-identity path for Power Platform connectors turned out to be an
unreliable preview feature (see [ADR-0006](adr/0006-copilot-connector-managed-identity.md),
superseded by [ADR-0007](adr/0007-copilot-connector-client-secret.md)), so that one integration
uses a client secret stored in Key Vault — one exception, documented, not a silent departure
from the pattern.

## Authorization: App Roles

Three Entra ID App Roles, defined once in `infra/entra/app-roles.json` and provisioned via
`scripts/setup-entra-app.ps1`:

| Role | Value | Intent |
|---|---|---|
| Admin | `Admin` | Full administrative access: agent/tool configuration, user and role management, audit log access |
| Agent User | `Agent.User` | Interact with agents, view own conversation history |
| Auditor | `Auditor` | Read-only access to audit logs and configuration, for compliance review |

These are enforced in the API (`apps/api/app/auth.py`) via the token's `roles` claim, not
custom claims or a separate authorization service — see
[`docs/diagrams/auth-sequence.md`](diagrams/auth-sequence.md) for the full request flow.

**Dataverse mirroring:** the same three role names are planned as Dataverse security roles,
created in Milestone 7 alongside the actual business-data tables they'd govern. Creating
them now would mean empty, privilege-less role objects with nothing meaningful to attach —
security roles in Dataverse are fundamentally table-privilege sets, and no custom tables
exist yet. Deferring avoids doing the same work twice; the naming convention (`Admin`,
`Agent.User`, `Auditor`) is fixed now specifically so the eventual mapping is unambiguous.

## Token validation

`apps/api/app/auth.py` validates, on every request:
1. **Signature** — against the tenant's JWKS (`https://login.microsoftonline.com/<tenant>/discovery/v2.0/keys`), fetched and cached via `PyJWKClient`.
2. **Issuer** — must match `https://login.microsoftonline.com/<tenant>/v2.0`.
3. **Audience** — must match `api://<api-client-id>`.
4. **Expiry** — standard JWT `exp` claim, enforced by `PyJWT`.

Only after all four pass does the `roles` claim get checked for authorization. Automated
tests (`apps/api/tests/test_auth.py`) cover: missing token (401), wrong audience (401),
expired token (401), valid token without the required role (403), and valid token with the
required role (200) — not just the happy path.

## Agent orchestration (Milestone 2)

The `/agent/chat` endpoint (Semantic Kernel, `apps/api/app/agent.py`) requires `Admin` or
`Agent.User` — see [`docs/diagrams/agent-chat-sequence.md`](diagrams/agent-chat-sequence.md)
for the full request path from client through APIM to Azure OpenAI. Same token-validation
and RBAC enforcement as every other route; the only new element is the API's own outbound
call to Azure OpenAI, which is itself managed-identity-authenticated (see Identity, above).

## Secrets and configuration

- **Local development**: real values live only in `.env` (gitignored), never in source,
  config defaults, or documentation. Enforced by `.githooks/pre-commit`, which reads `.env`
  fresh on every commit and blocks it if the staged diff contains any real value from it.
- **Azure**: Key Vault (RBAC-authorized, purge protection on) holds any secret material that
  can't be avoided entirely via managed identity. No secrets are hardcoded into Bicep — every
  environment-specific value is a parameter sourced from `.env`/`azd env`.
- **CI/CD** *(planned)*: GitHub↔Azure authentication via OIDC federated credentials
  (`azd pipeline config`), not long-lived stored secrets — see `manual-setup.md` #7.

## Network and transport

- All Azure endpoints are HTTPS-only by default (Key Vault, APIM, Container Apps, Dataverse,
  Azure OpenAI).
- APIM sits in front of the API as the single ingress point, forwarding to the Container App
  via a `set-backend-service` passthrough policy (`infra/modules/apim-api.bicep`). Per-route
  policies (rate limiting, IP restrictions, request/response transformation) attach here in a
  later milestone if a concrete need appears — not needed yet with a single backend.
- Public network access is currently `Enabled` on Key Vault/ACR/Azure OpenAI for development
  simplicity (documented trade-off, not an oversight); revisit with Private Link if this
  moved toward a production posture.

## Data protection

- Key Vault: soft-delete + purge protection on (see `PROJECT_JOURNAL.md` Milestone 0 for why
  purge protection specifically is now an Azure platform default, not optional).
- Dataverse: encryption at rest is a Microsoft-managed platform default for all environments.
- Azure AI Content Safety *(evaluate, per ADR-0001)* — not yet implemented; revisit once the
  LLM-facing endpoints exist (Milestone 2+).

## Auditing *(planned)*

- Dataverse has built-in auditing (entity/record-level change tracking) — evaluate enabling
  it directly rather than building custom audit logging, per the Microsoft Platform
  Evaluation principle (ADR-0001).
- Azure-side audit trail: Application Insights request/dependency logging (already live from
  Milestone 0) plus Azure Activity Log for control-plane changes (RBAC, resource changes) —
  no additional work needed, just needs to be surfaced in the eventual admin console
  (Milestone 7).

## Known limitations at this milestone

- No Conditional Access / MFA policy configured on the Entra tenant (Entra ID Free tier
  covers this project's needs; Conditional Access requires P1, out of scope for a $0-minded
  portfolio build).
- No Privileged Identity Management (PIM) — the demo users hold their App Role assignments
  as standing access, not just-in-time. Acceptable for a two-person portfolio sandbox;
  would be a real recommendation for a production engagement.
- Dataverse security roles not yet created (see above — deferred to Milestone 7 by design).
- APIM runs a single passthrough policy; no per-route rate limiting, IP filtering, or
  transformation yet — authorization is enforced entirely at the API layer for now.
- Azure OpenAI content moderation relies on the platform default (`raiPolicyName:
  Microsoft.Default`) — Azure AI Content Safety as a dedicated evaluated layer is still
  planned, not implemented.
