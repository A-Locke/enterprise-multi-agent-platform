# Changelog

All notable changes to this project are documented in this file. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased] — Milestone 3: Copilot Studio Agent

### Added
- ADR-0006: Copilot Studio custom connector uses managed identity + federated credential instead of a client secret — the connector calls the API as the signed-in user (preserving Milestone 1's per-user RBAC) without introducing this project's first stored secret. Reuses the existing API app registration.
- `power-platform/solutions/connectors/platform-api/`: custom connector definition (Swagger 2.0 + OAuth AAD properties), templated with placeholders, created live via `pac connector create`.
- `scripts/setup-copilot-connector.ps1`: generates the real connector files from templates and creates or updates the connector (idempotent).

### Fixed
- Connector's OAuth resource fields (`AzureActiveDirectoryResourceId`, `resourceUri`) used the App ID URI form (`api://<client-id>`), which Entra rejects for self-referential token requests (`AADSTS90009`) when client and resource are the same app. Changed to the bare client-id GUID — the same underlying platform behavior Milestone 1 already documented from a different angle.
- Reusing the API app as its own OAuth client also needs its own `access_as_user` scope explicitly listed under its own API permissions (`AADSTS650057` otherwise) — exposing a scope isn't the same as being permitted to request it against yourself. Folded into `scripts/setup-entra-app.ps1` (idempotent) rather than left as a one-off CLI fix.
- Apps created via `az ad app create` don't get the Microsoft Graph `User.Read` ("Sign in and read user profile") delegated permission that portal-created apps receive by default — without it, sign-in fails outright (`AADSTS90008`). Added and granted, also folded into `scripts/setup-entra-app.ps1`.
- The app registration had no reply URL at all (`AADSTS500113`) — it was created purely as an API resource, never as an OAuth client. Registered Power Platform's fixed custom-connector OAuth broker endpoint (`https://global.consent.azure-apim.net/redirect`), read-merge-write to preserve the connector-specific redirect URI expected once managed-identity auth lands. Also folded into `scripts/setup-entra-app.ps1`.

### Deferred (documented, not forgotten)
- Switching the connector to managed-identity auth is portal-only, no CLI surface found — `manual-setup.md` #9. Federated credential + redirect URI wiring is ready to script as soon as the portal-generated values exist.

## [Milestone 2] — 2026-08-04 — Core Orchestration

### Added
- ADR-0005: bare Azure OpenAI resource (`kind: 'OpenAI'`) over a full Azure AI Foundry project — nothing at this milestone's scope needs Foundry's added surface; the upgrade path is reversible.
- `infra/modules/ai.bicep`: Azure OpenAI resource + `gpt-5-mini` deployment (`GlobalStandard` SKU), `disableLocalAuth: true`, RBAC-only access (`Cognitive Services OpenAI User`).
- `infra/modules/container-apps-env.bicep`, `container-app-api.bicep`: Container Apps environment + the API's Container App, system-assigned managed identity, `AcrPull` + `Cognitive Services OpenAI User` RBAC.
- `infra/modules/apim-api.bicep`: APIM wired to the Container App via a passthrough backend/policy.
- `apps/api/app/agent.py`, `routers/agent.py`: Semantic Kernel orchestration, `POST /agent/chat` (requires `Admin` or `Agent.User`), authenticated to Azure OpenAI via managed identity — no API keys anywhere.
- `apps/api/Dockerfile`, `azure.yaml` `services.api`: containerization and `azd deploy` wiring.
- `docs/diagrams/agent-chat-sequence.md`: sequence diagram for the full agent request path.
- 4 new tests (`tests/test_agent.py`) — 11 total, Semantic Kernel call mocked, no real Azure calls in CI.

### Fixed
- `gpt-4.1-mini` (version `2025-04-14`) was listed in the region's model catalog but rejected at deploy time (`ServiceModelDeprecating`) — catalog presence doesn't imply deployability; switched to `gpt-5-mini` and started checking `lifecycleStatus` explicitly.
- `gpt-5-mini` had zero default quota under `DataZoneStandard` (EU-only residency) but 500 under `GlobalStandard` on this subscription — switched SKU, documented as a real trade-off (ADR-0005), not a silent substitution.
- Container App stuck in a failed state after "Operation expired" on first provision — deleting and letting Bicep recreate it resolved it.
- ACR Tasks (remote build) disabled entirely on this subscription — fell back to local Docker build.
- Chicken-and-egg on the Container App's ACR `registries` block (referencing a managed identity that didn't exist yet in the same deployment) — resolved by omitting it on first provision, adding it back once `AcrPull` RBAC existed and settled.
- APIM `method: '*'` is not a real wildcard — silently matched nothing, every request 404'd at the gateway. Needed one explicit operation per HTTP method.

### Verified
- End-to-end through the live APIM gateway with a real Entra ID token: `/me`, `/admin/ping`, and `/agent/chat` all correct, including a real generated reply from `gpt-5-mini`. Unauthenticated requests to protected routes correctly return `401` at the deployed edge, not just locally.

## [Milestone 1] — 2026-08-04 — Identity & Access

### Added
- Entra ID app registration for the platform API (App Roles: Admin, Agent.User, Auditor; delegated `access_as_user` scope), created via `scripts/setup-entra-app.ps1` (idempotent, handles demo role assignments).
- `apps/api`: FastAPI backend validating Entra ID bearer tokens (issuer/audience/signature against tenant JWKS) with role-based authorization. 7 passing tests.
- `scripts/demo-auth.ps1`: OAuth2 device-code flow demo (no MSAL dependency) for end-to-end auth verification.
- `.githooks/pre-commit`: blocks commits containing real values from `.env`, self-installed via `scripts/load-env.ps1` — defense-in-depth so local configuration values can never accidentally reach a commit.
- `docs/security-model.md` and `docs/diagrams/auth-sequence.md`: security model documentation and end-to-end auth sequence diagram.
- CI: `test-api` job (ruff, mypy, pytest) added to `.github/workflows/ci.yml`.

### Fixed
- `apps/api/app/config.py`: audience validation only accepted the `api://<client-id>` App ID URI form; live verification (not just unit tests) surfaced that Entra ID actually issues the bare client-id GUID for this app's own exposed scope. Now accepts both.
- `apps/api/pyproject.toml`: `pytest` (CI's invocation) doesn't add the CWD to `sys.path` the way `python -m pytest` (local invocation) does — added `pythonpath = ["."]` so imports resolve consistently either way.

### Verified
- End-to-end against a real Entra ID token (not synthetic test tokens): `GET /me` and `GET /admin/ping` both behaved correctly for an Admin-role user.

### Deferred
- Dataverse security roles (Admin/Agent.User/Auditor mirroring the Entra App Roles) - creating them now would mean empty, privilege-less role objects since no custom Dataverse tables exist yet. Moved to Milestone 7, alongside the actual business-data model. See `PROJECT_JOURNAL.md`.

## [Milestone 0] — 2026-08-04 — Foundation

### Added
- Repository scaffold: `/infra`, `/apps/{api,functions,web}`, `/power-platform/{solutions,pipelines}`, `/docs/{adr,diagrams,deliverables}`, `/.github/workflows`.
- `README.md`, `manual-setup.md`, `CHANGELOG.md`, `PROJECT_JOURNAL.md`.
- ADR-0001: Microsoft Platform Evaluation principle.
- Local tooling installed: Azure CLI, Bicep CLI, Azure Developer CLI (`azd`), Power Platform CLI (`pac`).
- `docs/cost-analysis.md`: per-resource free-tier/cost breakdown targeting $0/month sustained spend.

- `.env.example` and `scripts/load-env.ps1`: local configuration template and PowerShell loader (no native `.env` sourcing on Windows) — single source of truth for subscription/tenant IDs, region, and Bicep parameter values.
- ADR-0003: two-tenant strategy — Azure resources stay in the personal-account-derived tenant (preserves the $200 credit); Power Platform/Copilot Studio/M365 use a separate Microsoft 365 Developer Program tenant, since Power Platform rejects personal Microsoft accounts (`AADSTS500200`). **Superseded same-day by ADR-0004** after the M365 Developer Program's instant sandbox rejected the account with no appeal path.
- ADR-0004: single-tenant resolution — create a new organizational user inside the existing Azure tenant and use it to sign up for the Power Apps Developer Plan (a different, ungated signup flow), avoiding a second tenant entirely. `manual-setup.md` and `.env`/`.env.example` updated accordingly. Dataverse Developer environment provisioned and live.

### Changed
- ADR-0002: revised cost policy — prefer Azure-native services (e.g. ACR over GitHub Container Registry) within the 30-day, $200-credit build window, with up to $20 out-of-pocket accepted. `docs/cost-analysis.md` updated accordingly.
- `infra/main.bicep`: added Azure Container Registry (Basic) and an `Microsoft.Consumption/budgets` guardrail (alerts at 50/75/90/100% of a $180 default ceiling, environment-driven notification email).
- `infra/modules/key-vault.bicep`: `enablePurgeProtection` flipped to `true` — Azure now rejects `false` on new vaults as a platform default (not a subscription policy — confirmed empty via `az policy assignment list`).

### Deployed
- `azd provision` succeeded against `rg-dev` (France Central): Key Vault, Container Registry, Log Analytics + Application Insights, API Management (Consumption), and the Cost Management budget guardrail. First real Azure infrastructure live.
