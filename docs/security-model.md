# Security Model

Living document — grows with each milestone. Current state reflects Milestone 10
(Hardening & Docs finalization).

## Identity

Single Microsoft Entra ID tenant hosts both Azure resources and Power Platform/Dataverse
(ADR-0004) — no cross-tenant identity federation needed for this project's scope.

Three categories of principal exist today:
- **Human users**, authenticating interactively (device-code flow today; authorization-code
  + PKCE for any future browser client).
- **Workload identities (Azure)**: the API's Container App uses a **system-assigned managed
  identity** for its Azure dependencies — `AcrPull` on the Container Registry (image pulls),
  `Cognitive Services OpenAI User` on the Azure OpenAI resource (chat completions), and
  `Cognitive Services User` on the Content Safety resource (moderation checks, Milestone 10 —
  see [ADR-0014](adr/0014-content-safety.md)). Locally, the same code path authenticates via
  the developer's own `az login` session (`DefaultAzureCredential`'s fallback chain) — no
  separate cloud/local auth branches to maintain, and no API keys anywhere: every Cognitive
  Services resource in this project has `disableLocalAuth: true`, so key-based auth isn't
  even a configuration option that exists to misuse.
- **Workload identities (CI/CD pipelines)**: two dedicated identities, one per release
  pipeline (Milestone 9 — see [ADR-0013](adr/0013-combined-release-process.md)):
  - A User-Assigned Managed Identity with GitHub OIDC federated credentials
    (`msi-<project>`, its own resource group), holding `Contributor` and `Role Based Access
    Control Administrator` scoped to `rg-dev` only — no stored Azure secret.
  - A dedicated Entra app registration, registered as a Dataverse **Application User**
    (System Administrator) in both Power Platform environments, authenticating via
    client-credentials — the one standing secret this project's CI holds, stored in Key
    Vault and as a GitHub secret, never in source.

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

**Dataverse mirroring:** the same three role names exist as real Dataverse security roles
(`Admin`, `Agent.User`, `Auditor`), created in Milestone 7 alongside the Agent Configuration
and Conversation Audit Log tables they govern — see [ADR-0012](adr/0012-dataverse-business-data.md).
Row-level security is enforced by Dataverse natively (e.g. `Agent.User` sees only their own
audit entries, not everyone's), not by application logic. These roles are provisioned in
both Power Platform environments now that a real dev→test promotion pipeline exists
(Milestone 9), captured as a source-controlled solution
(`power-platform/solutions/business-data`) rather than authored twice by hand.

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

## Agent orchestration (Milestone 2, hardened in Milestone 10)

The `/agent/chat` endpoint (Semantic Kernel, `apps/api/app/agent.py`) requires `Admin` or
`Agent.User` — see [`docs/diagrams/agent-chat-sequence.md`](diagrams/agent-chat-sequence.md)
for the full request path from client through APIM to Azure OpenAI. Same token-validation
and RBAC enforcement as every other route; the API's own outbound calls (Azure OpenAI,
Content Safety) are both managed-identity-authenticated (see Identity, above).

As of Milestone 10, every request to `/agent/chat` is checked against **Azure AI Content
Safety** (`apps/api/app/content_safety.py`) before the message reaches the model — see
[ADR-0014](adr/0014-content-safety.md) for the threshold and fail-open rationale. This is in
addition to, not instead of, Azure OpenAI's own default content filter at the model layer.
Copilot Studio conversations (this platform's primary conversational surface) are not routed
through this check — see Known limitations, below.

## Secrets and configuration

- **Local development**: real values live only in `.env` (gitignored), never in source,
  config defaults, or documentation. Enforced by `.githooks/pre-commit`, which reads `.env`
  fresh on every commit and blocks it if the staged diff contains any real value from it.
- **Azure**: Key Vault (RBAC-authorized, purge protection on) holds any secret material that
  can't be avoided entirely via managed identity. No secrets are hardcoded into Bicep — every
  environment-specific value is a parameter sourced from `.env`/`azd env`.
- **CI/CD**: GitHub↔Azure authentication via OIDC federated credentials (no stored Azure
  secret) and a dedicated Dataverse Application User for the Power Platform pipeline (one
  standing secret, Key Vault + GitHub secret) — see [ADR-0013](adr/0013-combined-release-process.md)
  and `manual-setup.md` #7. Both `azure-dev.yml` and `power-platform-deploy.yml` are
  `workflow_dispatch`-only (deliberate, reviewed deployments), not auto-deploy-on-push.

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
- **Azure AI Content Safety** — implemented Milestone 10, see [ADR-0014](adr/0014-content-safety.md).
  Input moderation on the pro-code `/agent/chat` endpoint; Copilot Studio's own moderation is
  a separate, Microsoft-managed platform feature outside this project's code.

## Auditing

- **Dataverse Conversation Audit Log** (Milestone 7 table, wired to real agent conversations
  in Milestone 8): a real Dataverse table logging agent/user/outcome per conversation, with
  row-level security (`Agent.User` sees only their own entries, `Auditor` sees everyone's) —
  see [ADR-0012](adr/0012-dataverse-business-data.md) and `PROJECT_JOURNAL.md` Milestone 8
  for the orphaned-column bug hit and fixed along the way.
- Dataverse's own built-in auditing (entity/record-level change tracking) is a separate,
  native platform capability, evaluated but not additionally enabled — the Conversation
  Audit Log table above already covers this project's actual audit need without it.
- Azure-side audit trail: Application Insights request/dependency logging plus Azure Activity
  Log for control-plane changes (RBAC, resource changes). **Known gap** (Milestone 8): Azure
  Monitor alerting is live (`infra/modules/monitoring.bicep`), but Application Insights has
  been provisioned since Milestone 0 without ever being wired into the API's application code
  — request/dependency tracing isn't actually flowing yet, despite the resource existing. See
  `docs/observability.md`.

## Known limitations at this milestone

- No Conditional Access / MFA policy configured on the Entra tenant (Entra ID Free tier
  covers this project's needs; Conditional Access requires P1, out of scope for a $0-minded
  portfolio build).
- No Privileged Identity Management (PIM) — human demo users and the CI/CD workload
  identities alike hold standing access rather than just-in-time. Acceptable for a
  single-person portfolio sandbox; a real production engagement would recommend PIM for the
  workload identities specifically, given they hold real write access (RBAC Administrator,
  Dataverse System Administrator — see Identity, above).
- APIM runs a single passthrough policy; no per-route rate limiting, IP filtering, or
  transformation yet — authorization is enforced entirely at the API layer for now.
- Content Safety covers the pro-code `/agent/chat` endpoint's input only, not output, and not
  Copilot Studio conversations at all (a separate, Microsoft-managed moderation layer outside
  this project's code) — see [ADR-0014](adr/0014-content-safety.md).
- Public network access is `Enabled` on Key Vault/ACR/Azure OpenAI/Content Safety/AI Search
  for development simplicity — a documented trade-off (see Network and transport, below), not
  an oversight; Private Link is the real recommendation for a production posture.
- The two CI/CD workload identities (Milestone 9) hold real write access scoped as narrowly
  as practical (`rg-dev` only for the Azure MSI; both Dataverse environments only for the
  Power Platform service principal) but are still standing credentials with genuine blast
  radius if compromised — both are explicitly in scope for the project teardown plan when
  this project concludes.
