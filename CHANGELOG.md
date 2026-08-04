# Changelog

All notable changes to this project are documented in this file. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased] — Milestone 1: Identity & Access

### Added
- Entra ID app registration for the platform API (App Roles: Admin, Agent.User, Auditor; delegated `access_as_user` scope), created via `scripts/setup-entra-app.ps1` (idempotent, handles demo role assignments).
- `apps/api`: FastAPI backend validating Entra ID bearer tokens (issuer/audience/signature against tenant JWKS) with role-based authorization. 7 passing tests.
- `scripts/demo-auth.ps1`: OAuth2 device-code flow demo (no MSAL dependency) for end-to-end auth verification.
- `.githooks/pre-commit`: blocks commits containing real values from `.env`, self-installed via `scripts/load-env.ps1` — defense-in-depth so local configuration values can never accidentally reach a commit.
- `docs/security-model.md` and `docs/diagrams/auth-sequence.md`: security model documentation and end-to-end auth sequence diagram.
- CI: `test-api` job (ruff, mypy, pytest) added to `.github/workflows/ci.yml`.

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
