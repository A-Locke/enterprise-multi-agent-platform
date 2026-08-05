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

**Status:** complete
**Date started:** 2026-08-04
**Date completed:** 2026-08-05

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

### Third bug: no Microsoft Graph permission at all

Past both self-reference issues, sign-in failed again with `AADSTS90008: ... must require
access to Microsoft Graph by specifying at least 'Sign in and read user profile'
permission.` `az ad app permission list` confirmed the app had exactly one permission — its
own self-referencing scope — and nothing pointing at Microsoft Graph. Apps created via
`az ad app create` don't get the `User.Read` delegated permission that portal-created apps
receive automatically; without it, Entra's consent screen has no baseline profile scope to
show and the sign-in flow refuses to proceed. Fixed the same way as the other two: `az ad app
permission add` (Microsoft Graph's well-known app ID `00000003-0000-0000-c000-000000000000`,
scope `e1fe6dd8-ba31-4d61-89e7-88639da4683d` / `User.Read`) followed by `az ad app permission
grant --scope User.Read`. Folded into `scripts/setup-entra-app.ps1` as a third idempotent
block, re-ran the script to confirm all three checks now skip cleanly on a second pass.

### Fourth bug: no reply address registered

Past the consent screen, sign-in failed with `AADSTS500113: No reply address is registered
for the application.` `az ad app show --query web.redirectUris` confirmed the list was
empty — unsurprising, since this app registration started life purely as an API resource,
never as an OAuth client with a UI to redirect back to. Power Platform's custom-connector
OAuth broker (AAD identity provider) redirects through a fixed, documented Microsoft
endpoint regardless of which connector or tenant is involved:
`https://global.consent.azure-apim.net/redirect`. Registered it as a reply URL via `az ad app
update --web-redirect-uris`. Folded into `scripts/setup-entra-app.ps1` as a fourth idempotent
block — read-merge-write rather than a blind overwrite, since `--web-redirect-uris` replaces
the entire list and a second, connector-specific redirect URI is still expected to land here
later once the connector switches to managed-identity auth (ADR-0006, `manual-setup.md` #9).

### Correction: the bare redirect URI wasn't actually enough

Sign-in still failed, now with `AADSTS50011: The redirect URI
'https://global.consent.azure-apim.net/redirect/<connector-specific-suffix>'
... does not match the redirect URIs configured for the application` — a different, longer
URL than the bare one just registered. Asked to research rather than guess again before
touching the app a fifth time. Microsoft's own custom-connector AAD-auth doc
(`learn.microsoft.com/en-us/connectors/custom-connectors/azure-active-directory-authentication`)
confirms the bare `.../redirect` endpoint was never the real requirement — Power Platform
generates a **connector-specific** redirect URL (a unique suffix per connector) that has to
be copied from the connector's Security tab and registered instead. It's stable across
connector updates (per the same doc), so it only needs registering once — same lifecycle as
the bare one, just not interchangeable with it. The AADSTS50011 error had already echoed the
exact value back verbatim, so no portal trip was needed to retrieve it. Registered it
alongside the bare URI (both are harmless to keep; Microsoft's own worked example registers
both). Stored the real value in `.env` as `COPILOT_CONNECTOR_REDIRECT_URI` (gitignored, not
hardcoded into the script) with a placeholder added to `.env.example`, and updated
`scripts/setup-entra-app.ps1`'s redirect-URI block to register it from the environment when
present. Re-ran the script to confirm both URIs now skip cleanly.

### Fifth bug, and a pivot away from managed identity

Past all four redirect/permission issues, sign-in reached actual token exchange and failed
with `AADSTS7000215: Invalid client secret provided` — expected, since the connector was
never given a secret (managed identity was always the plan). Attempting the portal-only
managed-identity switch from ADR-0006 didn't go as documented: the current maker portal
didn't surface a Security tab for the connector at all, and a prior attempt through it
**deleted the connector outright** rather than failing safely — confirmed via `pac connector
list` returning nothing afterward. Asked to research before touching anything again rather
than retry blind a fifth time.

Research (Microsoft's own custom-connector AAD-auth doc, plus real examples pulled from
`microsoft/PowerPlatformConnectors`) confirmed managed identity is labeled **"Managed
Identity (Preview)"** — undocumented, no CLI surface, and apparently not reliably reachable
in the current portal for this connector. Decided with the user to fall back to standard
client-secret OAuth instead, backed by Key Vault rather than a secret that exists only as a
value once pasted into a portal field. Wrote [ADR-0007](docs/adr/0007-copilot-connector-client-secret.md),
marked ADR-0006 superseded.

Implementation: generated an Entra client secret (`az ad app credential reset --append`) and
stored it in Key Vault, never in a file that could be committed. Storing it required a Key
Vault RBAC grant (`Key Vault Secrets Officer`) for the local dev principal — same pattern as
the Milestone 2 Azure OpenAI grant, confirmed with the user before running since it's a new
role assignment. Hit an unrelated Git Bash gotcha along the way: `az role assignment create
--scope /subscriptions/...` failed with a nonsensical `MissingSubscription` error until
`MSYS_NO_PATHCONV=1` stopped Git Bash's MSYS layer from mangling the leading-slash resource
ID into a Windows path.

Checked real `microsoft/PowerPlatformConnectors` examples for the `aad` identity provider
before assuming a `clientSecret` field belonged in `apiProperties.json` — it doesn't; the
secret has always been a portal-only field (confirmed against the original ADR-0006 tutorial
too), never part of the connector definition. Re-ran `scripts/setup-copilot-connector.ps1`,
which found and updated a connector — `pac connector download` confirmed its live definition
(client ID, tenant, scopes) and, notably, its redirect URL still matched the one already
registered on the Entra app exactly, so no further Entra-side changes were needed there.

Assumed at the time that the still-missing Security tab meant nothing existed there to show a
tab for. That guess was wrong: the screenshots turned out to be the **Connection** creation
dialog ("+ New connection"), a different screen entirely from the connector's own edit view.
The real path is the pencil-icon **Edit** on the Custom Connectors list, which opens a
multi-step editor (**1. General → 2. Security → 3. Definition → …**) — Security was there all
along, just not where we were looking.

### Client secret verified, then one more look at managed identity

With the real Security tab found, the tenant ID and scope fields turned out to be showing as
unset in the form (despite being correctly set in the underlying JSON via `pac connector
update`) — filled them in from the real, gitignored `apiProperties.json`, along with the
client secret the form required to save at all. Created a Connection: signed in successfully,
confirming the whole chain (redirect URI, permissions, consent, token exchange) works
end-to-end under client-secret auth.

With that known-good state in hand, tried the managed-identity switch once more, carefully.
It succeeded this time — no deletion, a "Managed identity" Issuer/Subject/Audience box
appeared. But re-opening the connector afterward, the managed-identity option had reverted:
back to demanding a client secret, with the toggle to choose managed identity gone entirely.
Nothing had been touched in between. Second unsafe-failure mode from the same preview
feature (first: deletes the connector; now: silently reverts a saved setting) — concrete,
not just documentation caveats. Re-entered the client secret, saved, confirmed a fresh
Connection still works. Wrote this up as an addendum to
[ADR-0007](docs/adr/0007-copilot-connector-client-secret.md) — the decision doesn't change,
now with firsthand evidence backing it rather than just Microsoft's "(Preview)" label.

### Authoring the agent: a four-layer licensing maze

Created the "Enterprise Multi-Agent Platform" agent in Copilot Studio, added the connector's
`AgentChat` action as a Tool, and immediately hit `You don't have permission to create agents
/ User license not found` on every save. This turned out to require four independent,
unrelated permission systems, each found by hitting its specific failure in turn rather than
from any single checklist: a **Copilot Studio authors** Entra security group (tenant setting),
a **Copilot Studio license/trial** (per-user, Microsoft 365 admin center), **pay-as-you-go
billing** linked to an Azure subscription (for *publishing* specifically, not creating), and a
**Microsoft 365 billing-account role** (needed just to complete a €0.00 trial checkout — a
permanently-disabled "Try now" button turned out to be a missing address field on the billing
account, not a Copilot Studio issue at all).

Working through this also required a subscription-wide **Contributor** RBAC grant for the
Power Platform admin account (it had zero Azure RBAC — a separate organizational user from
Milestone 0/ADR-0004) — confirmed explicitly with the user before applying, since it's much
broader than any prior grant this session. Hit the same Git Bash `/subscriptions/...`
path-mangling gotcha as before (`MSYS_NO_PATHCONV=1` again).

Full writeup, including the finding that the pay-as-you-go piece was likely unnecessary for
what this milestone actually needed, in
[ADR-0008](docs/adr/0008-copilot-studio-licensing.md).

### Tool-call timeout: cold start, not a config bug

Once saving worked, the first real tool-call test failed with `ConnectorTimeout` after
exactly 30 seconds — including a same-session retry, which argued against a simple cold
start (a warm retry should be fast). Checked `az containerapp replica list`: zero replicas
running. Checked Log Analytics: a fresh container startup logged right around the test
window, no request-processing log line — consistent with the *entire* cold start (image
pull, Semantic Kernel init, first Azure OpenAI call) eating the whole 30-second budget before
a response could return, catching both the original attempt and the quick retry in the same
still-warming window. Researched whether Copilot Studio's tool-call timeout is configurable
via the connector's Swagger definition — it isn't; this appears to be a fixed limit in
Copilot Studio's own orchestration layer, not something `apiDefinition.json` can override.

Fix: raised the Container App's `minReplicas` from 0 to 1 (`infra/modules/container-app-api.bicep`,
applied live via `az containerapp update` since `azd provision` unexpectedly required Docker
for what should have been a Bicep-only change). Confirmed spend impact negligible first
(€0.11 total spend against the €180 budget) before applying — trades scale-to-zero for a
small ongoing cost, documented in `docs/cost-analysis.md`. Retest succeeded immediately after.

### Publishing: two dead ends, one working answer

**Demo Website** channel: publish succeeded, but the shared link showed "You don't have
access to talk to this bot, contact the owner" — not our API's RBAC, but Copilot Studio's own
Share/permission list (deliberately left at admin-only). Root cause: Demo Website requires
disabling the agent's own authentication entirely (a hard platform requirement, confirmed via
an explicit banner in the publish dialog), which strips out the very identity the Share list
needs to recognize — and, more fundamentally, would strip out the identity our connector's
per-user delegated auth depends on too. Structurally incompatible with this project's design,
not a bug to work around.

**Teams + Microsoft 365** channel: enabled cleanly, but signing in to teams.microsoft.com as
the Power Platform admin account failed with `We couldn't find a Microsoft account` (web) and
a generic error code (desktop app). Almost certainly another symptom of this tenant's
personal-account origin (ADR-0004) confusing Teams' personal-vs-work-account sign-in
detection, not a new mistake. Not pursued further — not required for any later milestone
(Milestones 4+ continue via the Preview pane; Milestone 6's Graph integration is unrelated to
signing into Teams as a user), and only potentially relevant again for a Milestone 10 demo
recording, at which point it can be revisited fresh.

**Decision:** the Preview pane's already-successful test (post-`minReplicas` fix) is
sufficient evidence of the actual architectural claim — Copilot Studio's per-user identity,
through the connector's delegated OAuth, through Milestone 1's Entra App Role check, through
Semantic Kernel, to a real Azure OpenAI response. Publishing to an externally-reachable
channel isn't something this milestone needs. Milestone 3 is complete on that basis.

### Next steps

- Full project teardown (delete all accounts, unlink billing, destroy the temporary payment card) planned for project completion, not before — tracked outside the repo.

## Milestone 4 — Multi-Agent Coordination

**Status:** in progress
**Date started:** 2026-08-05

### Architecture decision: Connected Agents, not pro-code routing

The obvious pragmatic choice — route between specialized capabilities inside `agent.py` using
Semantic Kernel plugins, keeping Copilot Studio as the thin single front door built in
Milestone 3 — was proposed first, specifically to avoid multiplying Milestone 3's
well-documented Copilot Studio operational friction (the licensing maze, the managed-identity
preview feature's two unsafe failure modes) across additional agents.

Explicitly rejected: this project exists to demonstrate Copilot Studio/Power Platform
competency specifically, and routing around Copilot Studio's own native multi-agent
capability into more comfortable pro-code territory undercuts that purpose, however real the
friction is. Per ADR-0001's governing principle, the Microsoft-native option is evaluated
first — and here, unlike cases where it's genuinely incapable, Connected Agents can do the
job. Full reasoning in [ADR-0009](docs/adr/0009-copilot-studio-connected-agents.md).

### Built: two Connected Agents, parent orchestrator instructions

Created two child agents in Copilot Studio — **Knowledge Agent** and **Enterprise Integration
Agent** — each with placeholder instructions (real capability lands in Milestones 5 and 6
respectively) but real, routing-critical descriptions, published, and wired to the Milestone 3
parent agent as Connected Agents.

Rewrote the parent's instructions to define the full orchestration pattern explicitly, per
Microsoft's own documented best practices (`learn.microsoft.com/en-us/microsoft-copilot-studio/guidance/multi-agent-patterns`)
rather than a vague "use child agents when relevant": explicit routing criteria per
domain, directive language (MUST/NEVER-style framing) telling subagents never to reply to the
user directly, and the parent's own invoke → wait → combine → respond sequence spelled out.
The existing platform connector/tool stayed on the parent rather than being duplicated onto a
child — it's the one pro-code integration point this project has, not a per-domain concern.

### Verified: routing works, including graceful degradation

Four targeted test messages (kept deliberately few — multi-agent turns cost meaningfully more
Copilot Credits than single-agent ones, since each hop is its own reasoning-model
invocation):

1. Knowledge-domain question → routed to Knowledge Agent, correctly reported the placeholder
   "no knowledge source connected" state (paraphrased by the model rather than verbatim, but
   substantively correct).
2. Enterprise-integration question → routed to Enterprise Integration Agent.
3. General question → routed to the existing platform tool (Milestone 3's connector), same
   path as before Connected Agents existed.
4. Domain-mismatch question (weather) → correctly fell through to the general tool rather than
   getting stuck between the two specialists, per Microsoft's own recommended test case.

### One recurrence of the tool-call timeout — isolated, not systemic

Test 3 hit the same 30-second `ConnectorTimeout` fixed in Milestone 3 (`minReplicas: 1`).
Checked `az containerapp replica list` — same replica, no crash. Checked Log Analytics: exactly
one container restart in the prior two hours, with successful `/agent/chat` requests both
immediately before and after it. Conclusion: `minReplicas: 1` eliminates the *guaranteed*
cold start after every idle period (the actual Milestone 3 bug), but doesn't give an absolute
guarantee against all restarts — Container Apps can still occasionally recycle a replica for
platform-level reasons (node patching, health-probe hiccups), a documented characteristic of
the service, not a config gap on our side. The test request landed in that narrow window;
Copilot Studio's own retry logic recovered automatically and returned a real response moments
later. Worth documenting honestly as a known residual limitation rather than claiming the
Milestone 3 fix is airtight — not worth chasing further given it self-heals gracefully.

### Next steps

- Milestone 5: real RAG capability for the Knowledge Agent (Azure AI Search + Blob + Functions ingestion).
- Milestone 6: real Microsoft Graph actions for the Enterprise Integration Agent.
- Sequence diagram for the full multi-agent path (parent → child → response) — deferred to accompany Milestone 5/6's real implementations rather than diagramming the placeholder state.
