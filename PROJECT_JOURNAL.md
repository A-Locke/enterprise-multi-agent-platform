# Project Journal

Chronological record of milestones, technical decisions, blockers, resolutions, and lessons learned. ADRs capture the *what/why* of individual decisions in detail (see [`docs/adr/`](docs/adr/)); this journal captures the narrative and sequencing.

---

## Milestone 0 — Foundation

**Status:** complete
**Date started:** 2026-08-04
**Date completed:** 2026-08-04

### Decisions

- **Architecture direction**: the platform is explicitly framed as a Microsoft AI Consultant portfolio piece, not a generic cloud-agnostic AI app. Every architectural capability evaluates the Microsoft-native platform service (Power Platform, Copilot Studio, Dataverse, Azure AI Foundry, etc.) before defaulting to custom pro-code — recorded as the governing principle in ADR-0001.
- **Hybrid architecture**: Copilot Studio (conversational layer, custom-engine-agent) + Semantic Kernel (pro-code orchestration) + Power Platform (Power Apps/Automate/Dataverse, low-code business layer) + Azure (APIM, AI Foundry/OpenAI, AI Search, Container Apps, Functions, Service Bus, Monitor), with two separate IaC/ALM tracks: Bicep+azd for Azure, Power Platform CLI + Build Tools for Power Platform.
- **Repo shape**: monorepo with `/infra`, `/apps`, `/power-platform`, `/docs` — chosen so a single milestone's diff can touch code, infra, and docs together, and the milestone-by-milestone history in this journal stays coherent.

### Blockers & resolutions

- **Local tooling gap**: none of Azure CLI, Bicep CLI, `azd`, or Power Platform CLI (`pac`) were installed on the dev machine at project start. Resolved by installing all four via `winget` (`Microsoft.AzureCLI`, `Microsoft.Azd`, `Microsoft.PowerAppsCLI`) plus `az bicep install` for Bicep. Verified: Azure CLI 2.89.0, azd 1.29.0, Bicep 0.46.1, Power Platform CLI 2.10.1.
- **Plan iteration**: the first architecture pass (Next.js + FastAPI + Semantic Kernel + Postgres) was technically sound but read as a generic Azure AI app rather than a Microsoft consulting engagement — it under-used Power Platform and treated Copilot Studio as optional rather than central. Revised twice based on direct feedback to make Power Platform (Power Apps, Power Automate, Dataverse, Copilot Studio) first-class, add APIM/Service Bus/ACR/Functions/AI Foundry/Fabric/Purview, and add consulting-style deliverables (executive overview, solution proposal, risk register) alongside the engineering docs. Lesson: for a role-targeted portfolio project, the platform-fit story matters as much as the technical correctness of the architecture.

### Known limitations

- No application code yet — this milestone is infrastructure foundation + tooling + governing ADRs only.
- Copilot Studio authoring not yet started (Milestone 3).
- Azure and Power Platform admin identities are currently split across two "hats" on the same tenant (the personal Microsoft account as Azure/tenant Global Admin, a separate organizational user as the Power Platform-facing account) — fine for a portfolio build, worth simplifying if this ever became a real team project.

### Addendum — cost analysis (2026-08-04)

Produced `docs/cost-analysis.md` targeting $0/month sustained cost by stacking the Azure free account ($200 credit + 12-months-free + always-free services), the Power Apps Developer Plan (free non-production Dataverse/Power Apps/Power Automate), Copilot Studio's free build/test mode, and GitHub Actions' free minutes. Every planned resource fits a free tier except: Azure Container Registry Basic (~$5/month flat — mitigated by using GitHub Container Registry instead), and LLM token usage on Azure OpenAI/AI Foundry (usage-driven, bounded by dev/demo-only calls and the $200 credit). Microsoft Fabric and Purview (both flagged for evaluation in ADR-0001) are expected to be evaluated and *not* implemented specifically to hold the $0 target, with that reasoning captured as an ADR when that milestone is reached. Recommended an Azure Cost Management budget with alert thresholds as an ongoing guardrail rather than a one-time estimate.

### Addendum — cost policy revision (2026-08-04)

The $0-at-all-costs framing was revised after clarifying that the build will happen within a 30-day window (fully covered by the Azure free account's $200 credit) and up to $20 out-of-pocket beyond that is acceptable. Wrote **ADR-0002** documenting the tie-breaker change: prefer Azure-native services over free-alternative workarounds when the only reason for the workaround was a small flat fee. Concretely, switched from "use GitHub Container Registry" to **Azure Container Registry (Basic)** for simpler managed-identity pull auth into Container Apps, and added a `Microsoft.Consumption/budgets` guardrail to `infra/main.bicep` (alerts at 50/75/90/100% of a $180 default ceiling — 90% of the credit — with an environment-driven notification email param). ADR-0001's Microsoft Platform Evaluation principle is explicitly unaffected: this only changes cost-driven tie-breaks, not architecture-fit decisions. `docs/cost-analysis.md` updated to match, and now expects a light Microsoft Fabric implementation (not just evaluation) to be feasible within the window given its 60-day trial capacity.

### Blocker — Power Platform rejects the personal-account Azure tenant (2026-08-04)

`az login`/`azd auth login` succeeded fine (the free Azure account's `.env` values — subscription ID and tenant ID — are populated), but `pac auth create` failed with `AADSTS500200: User account '<personal-account-email>' is a personal Microsoft account. Personal Microsoft accounts are not supported for this application`. Power Platform requires a real organizational (work/school) Entra account; a personal-account-derived Azure default directory doesn't qualify.

**Resolution:** wrote **ADR-0003** — accept two separate Entra ID tenants rather than risk the $200 Azure credit trying to consolidate. Azure resources stay in the existing personal-account tenant; a free, no-credit-card **Microsoft 365 Developer Program** sandbox tenant (90-day renewable, E5-licensed) will host Power Platform, Copilot Studio, and Teams/SharePoint/Exchange for the Graph milestone. `manual-setup.md` #1–#3 updated to reflect the two-tenant flow, and `.env`/`.env.example` now track `POWER_PLATFORM_TENANT_ID` / `POWER_PLATFORM_ADMIN_UPN` separately from `AZURE_TENANT_ID`. Lesson: a "free account" isn't a single fungible identity across all of Microsoft's platforms — Azure and Power Platform have different account-type requirements, worth checking before assuming one login covers everything.

**Next step (user-owned):** sign up at [developer.microsoft.com/microsoft-365/dev-program](https://developer.microsoft.com/microsoft-365/dev-program), then retry `pac auth create --name dev` with the new tenant's admin account.

### Blocker — M365 Developer Program instant sandbox rejected the account (2026-08-04)

The M365 Developer Program signup returned "You don't currently qualify for a Microsoft 365 Developer Program sandbox subscription" — an automated eligibility check with no manual override, so ADR-0003's second-tenant plan was a dead end.

**Resolution:** wrote **ADR-0004** (supersedes ADR-0003) — realized the actual fix didn't need a second tenant at all. The existing Azure tenant is already a real Entra ID directory; creating a new user *inside* it (e.g. `pp-admin@<tenant>.onmicrosoft.com`, Global Administrator) produces a genuine organizational account. Signing up for the **Power Apps Developer Plan** (a different, more permissive signup flow than the M365 Developer Program, no eligibility gate, no credit card) with that new user provisions a free Dataverse environment in the same tenant as all the Azure resources. Net result: single-tenant architecture, simpler RBAC story for Milestone 1 (real shared role definitions instead of cross-tenant mirrored ones), and no dependency on a program that already rejected the account. `manual-setup.md` and `.env`/`.env.example` updated again to match; `POWER_PLATFORM_TENANT_ID` removed since it's now the same as `AZURE_TENANT_ID`.

**Lesson:** when a Microsoft signup flow gives an opaque, unappealable rejection, look for a *different* signup flow for the same underlying capability before working around the rejection architecturally — the Developer Plan and the Developer Program sound similar but have very different eligibility rules.

**Next step (user-owned):** create the new Entra user + Global Admin role assignment in the Azure portal, sign up for the Power Apps Developer Plan with it, then retry `pac auth create --name dev`.

### Resolution — Power Platform environment provisioned (2026-08-04)

`pac auth create --name dev` succeeded with the new organizational user, confirming ADR-0004's fix worked — no second tenant needed.

Provisioning the actual Dataverse environment hit one more snag: this tenant (Switzerland-based) is in Microsoft's rollout group for a newer "macro region geography" requirement on environment creation (also affects Canada/Norway/France tenants). Both `pac admin create --region <name>` and the `make.preview.powerapps.com` quick-create panel rejected every region value tried (`us`, `europe`, `asia`, `unitedstates`, ...) with `macroRegion '...' is not valid` / `macroRegion must be specified` — the valid tokens for this newer field aren't documented anywhere public. Resolved by using the full **Environments → + New** wizard in [admin.powerplatform.microsoft.com](https://admin.powerplatform.microsoft.com) instead of the CLI or the preview-portal shortcut, and picking a value directly from its dynamically-populated Region dropdown rather than guessing a string.

**Result:** Dataverse environment live, recorded in `.env`. `manual-setup.md` #3 updated with this hiccup so a future reproduction doesn't burn the same time on it. Milestone 0's remaining manual prerequisites (Azure login, Power Platform auth, Dataverse environment) are now all satisfied.

### Blocker — Key Vault deployment rejected on first `azd provision` (2026-08-04)

First `azd provision` run: resource group, Container Registry, Log Analytics, Application Insights, and APIM all deployed successfully, but Key Vault failed: `The property "enablePurgeProtection" cannot be set to false. Enabling the purge protection for a vault is an irreversible action.` The error's own wording ("soft-deleted resource is causing a deployment conflict") suggested a leftover resource, but `az keyvault list-deleted` and `az policy assignment list` both came back empty — ruling out both a stale soft-deleted vault and a subscription-level policy. Concluded this is Azure now enforcing purge protection as a platform default on all new vaults, not a policy or leftover state.

**Resolution:** changed `infra/modules/key-vault.bicep` to `enablePurgeProtection: true` (accepted trade-off: this vault name can't be purged early after deletion). Re-ran `azd provision` — succeeded in 57 seconds, Key Vault included this time.

### Milestone 0 — provisioned and closed out (2026-08-04)

`azd provision` succeeded. Live in `rg-dev` (France Central): Key Vault, Container Registry, Log Analytics + App Insights, API Management Consumption tier, and the Cost Management budget guardrail ($180/month, confirmed via `az consumption budget list`). Region (`francecentral`) and publisher/budget contact details (`.env`) were filled in by the user; France Central chosen for solid Azure OpenAI/AI Foundry model availability and EU/EFTA data-residency alignment with the Power Platform environment.

Milestone 0 is complete: repo scaffold, governing ADRs (0001–0004), local tooling, both Azure and Power Platform environments live, and this first real infrastructure deployed and verified.

### Next steps

- Milestone 1: Entra ID app registrations + RBAC (App Roles), mirrored Dataverse security roles, end-to-end auth demo.

---

## Milestone 1 — Identity & Access

**Status:** in progress
**Date started:** 2026-08-04

### Progress so far

- Entra ID app registration for the platform API, with App Roles (Admin, Agent.User, Auditor) and a delegated `access_as_user` scope, created via `scripts/setup-entra-app.ps1` - idempotent, also handles demo role assignments via Microsoft Graph.
- FastAPI backend (`apps/api`) validates Entra ID bearer tokens against the tenant JWKS (issuer + audience + signature) and enforces role-based authorization via the `roles` claim. 7 passing tests cover missing-token, wrong-role, wrong-audience, and expired-token cases.
- `scripts/demo-auth.ps1` implements the OAuth2 device-code flow directly (no MSAL SDK dependency) for an end-to-end sign-in + API call demo.
- Added `.githooks/pre-commit` as a defense-in-depth control: reads `.env` fresh on every commit and blocks it if the staged diff contains any real value from it, so local configuration values can never accidentally reach a commit. Self-installs via `scripts/load-env.ps1`.
- `docs/security-model.md` and `docs/diagrams/auth-sequence.md`: security model documentation and a Mermaid sequence diagram for the end-to-end device-code auth flow.
- CI: added a `test-api` job (ruff, mypy, pytest) to `.github/workflows/ci.yml`, running against `apps/api` on every PR.

### Scoping decision - Dataverse security roles deferred to Milestone 7

Attempted to create the Dataverse-side "Admin/Agent.User/Auditor" security roles to mirror the Entra App Roles, but the Global Admin account isn't a synced Dataverse user (`The user is not a member of the organization` when calling the Dataverse Web API), so this specifically needs the org user's token, which needs another interactive sign-in.

Rather than push through that for a fairly low-value result right now: Dataverse security roles are fundamentally table-privilege sets, and no custom tables exist yet (that's Milestone 7's business-data-model work) - creating them now would mean empty, privilege-less role objects that get edited again later anyway. Deferred actual creation to Milestone 7, alongside the real data model they'd govern; fixed the role naming convention now (matching the Entra App Role values exactly) so the eventual mapping is unambiguous. Documented in `docs/security-model.md`.

### Bug found via live verification - audience claim format

Running `scripts/demo-auth.ps1` for real (not just the unit tests' synthetic tokens) surfaced a genuine bug: the API rejected a valid, correctly-signed, correctly-scoped token with "Audience doesn't match." Decoded the real token's claims to confirm: Entra ID issues the bare client-id GUID as `aud` for this app's own exposed scope in the device-code flow, not the `api://<client-id>` App ID URI form the API's config assumed. Fixed `Settings.audience` to accept both forms (PyJWT's `audience` param takes a list) rather than hardcode one observed behavior as the only valid case - other flows/configurations may still issue the `api://` form. Also added a debug claims printout to `scripts/demo-auth.ps1`, since decoding the actual token (rather than guessing from the error message) is what found the real cause in minutes instead of trial-and-error.

**Lesson:** the synthetic unit tests were internally consistent (they set `aud` to whatever `settings.audience` computed, so they'd pass even if that computation were wrong) but couldn't catch a mismatch between assumption and Entra's real behavior. Only a live token exposed it. Worth remembering for future auth-adjacent work: unit tests validate the code does what it's told; an end-to-end pass against the real identity provider validates the code was told the right thing.

### Milestone 1 - complete (2026-08-04)

Verified end-to-end against a real Entra ID token: `GET /me` returned the correct claims (`roles: ["Admin"]`), `GET /admin/ping` returned `200 {"message": "pong", "role": "Admin"}`. Identity and access control work for real, not just in tests.

**Delivered:** Entra ID app registration with App Roles, FastAPI bearer-token validation and role-based authorization (7 automated tests + live verification), device-code auth demo script, security model documentation, auth sequence diagram, CI job for the Python app, and a pre-commit hook protecting local configuration.

**Deferred to Milestone 7 (documented, not forgotten):** Dataverse security roles mirroring the Entra App Roles - deferred until real business-data tables exist for them to govern.

### Next steps

- Milestone 2: Azure AI Foundry project + model deployment, Semantic Kernel service behind APIM, one working custom agent end-to-end.
