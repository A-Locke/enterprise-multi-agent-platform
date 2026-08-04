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

---

## Milestone 2 — Core Orchestration

**Status:** complete
**Date:** 2026-08-04

### Decisions

- **ADR-0005**: bare Azure OpenAI resource (`kind: 'OpenAI'`) over a full Azure AI Foundry project, per the "evaluate, don't mandate" framing set in ADR-0004. Nothing at this milestone's scope (one orchestrator, one model) needs Foundry's added surface (multi-project governance, Agent Service, evaluation tooling); the upgrade path (`kind: 'AIServices'` + `allowProjectManagement: true`) is reversible and preserves the resource, so choosing simple now doesn't foreclose richer later.
- Authentication to Azure OpenAI is Entra ID RBAC only (`Cognitive Services OpenAI User`, `disableLocalAuth: true` on the resource) — no API keys exist as a configuration option, not just "unused." Same managed-identity pattern extended to ACR pulls for the Container App.

### Model selection: two real gates, not just a price check

First attempt (`gpt-4.1-mini`, version `2025-04-14`) was listed in `az cognitiveservices model list` for the target region but rejected at deploy time: `ServiceModelDeprecating`. The catalog listing doesn't surface deprecation status by default — checking `lifecycleStatus` per entry (not just presence) is what actually confirms deployability.

Switched to `gpt-5-mini` (`lifecycleStatus: GenerallyAvailable`), which then hit a second, different gate: zero default quota under `DataZoneStandard` (EU-only data residency), confirmed via `az cognitiveservices usage list`. `GlobalStandard` had 500 quota available on the same subscription for the same model. Used `GlobalStandard`, documented as a real trade-off (no EU-only processing guarantee) rather than a silent substitution — a production engagement with an actual EU-residency requirement would request the `DataZoneStandard` quota increase instead (portal-only, `manual-setup.md` #6).

### Deployment troubleshooting: four distinct issues, one deployment

Getting the Container App from "provisioned" to "actually serving traffic" surfaced a sequence of real, independent problems — worth recording distinctly since each had a different root cause and would mislead if conflated:

1. **Container App stuck failing with "Operation expired"** on the very first `azd provision`, even using a public placeholder image. Root cause never fully confirmed, but deleting the failed resource and letting Bicep recreate it from scratch resolved it cleanly on retry — consistent with a corrupted first-attempt resource state rather than a config error.
2. **`azd deploy`'s remote build (ACR Tasks) is disabled on this subscription entirely** (`TasksOperationsNotAllowed` — a platform restriction, not a config fix). Fell back to local Docker build, which meant starting Docker Desktop (installed but not running) before `azd deploy` could proceed.
3. **Chicken-and-egg on the ACR `registries` block**: configuring registry pull auth via the Container App's own not-yet-existent managed identity, in the same deployment that creates both, meant the registry validation had nothing to authenticate with yet. Resolved by leaving the `registries` block out of the *first* provision (safe, since the placeholder image is public and needs no registry) and adding it back once the `AcrPull` role assignment existed and had settled — confirmed by a clean second provision and a successful real-image pull.
4. **APIM operations silently matched nothing**: `method: '*'` is not a real wildcard in Azure API Management — every request 404'd at the gateway with a generic "Resource not found" despite the API and operation both existing and looking correctly configured. Needed one explicit operation per HTTP method (GET/POST/PUT/PATCH/DELETE), each with `urlTemplate: '/{*path}'`.

**Lesson across all four:** several of these produced *plausible-looking but wrong* diagnoses at first glance (the APIM 404 looked like a routing/path bug; the Container App failure looked like an ACR-permissions timing bug). What actually resolved each was checking ground truth directly — `az role assignment list`, `az apim api operation list`, `az containerapp revision list` — rather than reasoning from the error message alone. The one theory that turned out to be wrong (ACR registry validation blocking on RBAC propagation) was abandoned only after the fix didn't work and a different, correct fix was found — worth not being precious about an early hypothesis once evidence stops supporting it.

### Verified end-to-end (2026-08-04)

Confirmed independently, not just claimed:
- `GET /health` through the deployed Container App directly → `200`.
- `GET /health` through the APIM gateway (`/api/health`) → `200`.
- `GET /me` and `POST /agent/chat` through APIM **without** a token → `401` (auth enforced at the real deployed edge, not just locally).
- Full flow with a real Entra ID token through APIM: `/me` returned correct claims, `/admin/ping` returned `200`, and `/agent/chat` returned a real, coherent reply generated by `gpt-5-mini` via Semantic Kernel — the actual "one working agent end-to-end" goal of this milestone.

### Delivered

Azure OpenAI resource + `gpt-5-mini` deployment, Semantic Kernel orchestration (`apps/api/app/agent.py`) with managed-identity auth, Container Apps environment + Container App (system-assigned identity, `AcrPull` + `Cognitive Services OpenAI User` RBAC), APIM wired to the Container App with per-method passthrough operations, Dockerfile + `azure.yaml` service definition, 11 passing automated tests (agent chat mocked, no real Azure calls in CI), updated security model docs and a new agent-chat sequence diagram, and a live, independently-verified end-to-end path from a real token to a real model response.

### Next steps

- Milestone 3: Copilot Studio agent (low-code conversational layer), generative orchestration, custom action wired to the APIM-fronted backend (custom-engine-agent pattern), published to Teams/web.

---

## Milestone 3 — Copilot Studio Agent

**Status:** in progress (prep work done, portal authoring not started)
**Date started:** 2026-08-04

### Prep work: custom connector, automated as far as it goes

Unlike M0-M2, this milestone is genuinely maker-portal-only for the actual agent authoring (`manual-setup.md` #5) — no CLI/Bicep surface exists for that. Split the work: automate everything that can be, document precisely what can't.

**Design decision (ADR-0006):** the connector needs to call the API *as the signed-in user*, not as a generic service identity, or the per-user App Role authorization built in Milestone 1 gets bypassed rather than extended through Copilot Studio. That means OAuth 2.0 delegated auth on the connector — whose conventional setup wants a client secret, which would have been the first stored secret anywhere in this project. Found and used the newer alternative instead: managed identity + federated credential on the connector, same pattern already planned for GitHub-Azure OIDC, applied to a second trust relationship. Reused the existing API app registration rather than creating a new one — the managed-identity path doesn't need the public/confidential client split a secret-based setup would have pushed toward.

**Automated:** a Power Platform custom connector (`power-platform/solutions/connectors/platform-api/`) describing `/agent/chat`, created via `pac connector create`. Templated with placeholders (`<AZURE_API_APP_CLIENT_ID>`, `<APIM_HOSTNAME>`, etc.) rather than committing real values, consistent with the rest of the repo — `scripts/setup-copilot-connector.ps1` generates the real (gitignored) files from the templates and calls `pac`. Verified live via `pac connector list`.

Two small `pac` friction points along the way, both quick fixes: `pac connector create` rejects combining `--settings-file` with the individual `--api-definition-file`/`--api-properties-file` flags (use one or the other, not both — `settings.json` already references the other files by relative path); and the Swagger `info.title` has an undocumented 30-character limit, rejected with a generic error until trimmed.

### Remaining manual step (documented, not yet done)

Switching the connector's auth from client-secret (the default) to managed identity is a portal-only toggle with no CLI equivalent found — `manual-setup.md` #9. Once done, the resulting redirect URL + issuer + subject identifier get scripted into the Entra app registration (`az ad app update` for the redirect URI, `az ad app federated-credential create` for the trust) — those two calls are ready to run as soon as the values exist, just not before.

### Bug found via live sign-in attempt: self-referential token request

Trying to create a Connection from the connector failed at the sign-in popup: `AADSTS90009:
Application '<client-id>' is requesting a token for itself. This scenario is supported only
if resource is specified using the GUID based App Identifier.` Root cause: reusing the same
app registration as both the connector's client and the API resource means the token request
is self-referential, and Entra specifically rejects that when the resource is expressed as
the App ID URI (`api://<client-id>`) rather than the bare client-id GUID.

Recognized what was happening faster than the first time around specifically *because* it had
already been documented once: Milestone 1 hit the same underlying platform behavior from a
different angle (Entra issuing a bare-GUID `aud` claim instead of `api://` for this app's own
tokens), and that ADR/journal entry made this one easy to place. Fixed by changing
`AzureActiveDirectoryResourceId` and `resourceUri` in the connector's properties template to
the bare GUID (kept the `api://` form for `scopes`, a different field the error didn't
implicate). Made `scripts/setup-copilot-connector.ps1` idempotent (create-or-update by name)
along the way, since fixing this meant re-running it against an already-created connector.

**Lesson:** the value of writing these down isn't just for someone else — it paid off within
the same day, on a different Azure service, because the pattern ("self-referential app token
requests need the bare GUID, not the App ID URI") was recognizable on sight the second time.

### Second self-reference bug: the app also needs to list its own scope as a permission

Fixing the resource-identifier format got past `AADSTS90009` but immediately hit
`AADSTS650057: Invalid resource ... List of valid resources from app registration: `
(empty). The self-referencing pattern has a second sharp edge: an app acting as its own
OAuth client needs its own delegated scope explicitly listed under its *own* API permissions
(`requiredResourceAccess`) — exposing the scope (as a resource) isn't enough for the app to
also request it (as a client) against itself. Fixed with `az ad app permission add` (pointing
the app at itself as the API) followed by `az ad app permission grant --scope
access_as_user`, which pre-consents for all principals — no interactive admin-consent click
needed. Verified via `az ad app permission list`.

### Next steps

- User completes `manual-setup.md` #9 (managed-identity toggle in the portal) with the corrected connector.
- Wire the resulting redirect URI + federated credential into the app registration.
- Create and test a Connection.
- Author the actual Copilot Studio agent (topics, generative orchestration, wiring this connector as a custom action), publish to a demo channel.
