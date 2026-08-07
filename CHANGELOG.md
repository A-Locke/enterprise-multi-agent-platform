# Changelog

All notable changes to this project are documented in this file. Format loosely follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Milestone 10] — 2026-08-07 — Hardening & Docs finalization

### Added
- `infra/modules/content-safety.bicep`, `apps/api/app/content_safety.py`: Azure AI Content Safety, F0 tier, managed-identity auth, input moderation on `/agent/chat` (severity ≥ 2 blocks, fails open on service errors). ADR-0014. Deployed and verified live via the Milestone 9 OIDC pipeline.
- `apps/api/tests/test_content_safety.py`: unit coverage for the block/allow/fail-open paths. Required adding `pytest-asyncio` (`asyncio_mode = "auto"`) — this project's test suite had never needed direct async tests before.
- `docs/deliverables/`: eight consulting-facing deliverables (executive overview, solution proposal, assumptions and constraints, risk register, cost estimate, roadmap, technical handover, operations handover).
- `docs/demo-script.md`: beat-by-beat demo recording script.

### Changed
- `docs/security-model.md`: full refresh — Dataverse security roles and the CI/CD OIDC pipeline updated from "planned" to their real, implemented state; new Identity and Known limitations entries for both CI/CD workload identities.
- `docs/cost-analysis.md`: full refresh — Azure Functions/Service Bus/Fabric/Purview reframed from "planned" to "evaluated, not built" with their actual ADR-backed reasoning; added the second Dataverse environment, Content Safety, and both CI/CD identities; added an actual-spend section ($0.39 of $180 through Milestone 10).
- `README.md`: Status section rewritten (was stale since Milestone 2); documentation table updated with all docs added since.

Full detail on the Content Safety decision in [ADR-0014](docs/adr/0014-content-safety.md) and `PROJECT_JOURNAL.md`.

## [Milestone 9] — 2026-08-07 — ALM & Governance

### Added
- `.github/workflows/azure-dev.yml`: GitHub↔Azure OIDC deploy pipeline (`workflow_dispatch`-only), federated credentials on a dedicated User-Assigned Managed Identity — no stored Azure secret. Verified end-to-end (real `azd provision` + `azd deploy`).
- `.github/workflows/ci.yml`: `validate-deploy` job (`azd provision --preview`) and `validate-power-platform-solution` job (pack/unpack roundtrip, no live credentials).
- `.github/workflows/power-platform-deploy.yml`: Power Platform Build Tools promotion pipeline (`workflow_dispatch`-only), packs the business-data solution Managed and imports it into a new test Dataverse environment via a dedicated Application User service principal. Verified end-to-end (managed solution confirmed present in test via direct API query).
- Second Dataverse environment (`test-em-3b9dc26e`), free via a second Power Apps Developer Plan signup — same no-billing path as ADR-0004's original environment.
- `power-platform/solutions/business-data`: dual managed/unmanaged solution source (`--packagetype Both`), and a previously-missing SiteMap component for the Admin Console app module.
- ADR-0013: combined release process, documenting both pipelines and the full chain of real issues hit standing them up.

### Fixed
- A bulk GitHub Secrets migration had silently corrupted several secrets (`AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_ENV_NAME`, `AZURE_LOCATION`, `AZURE_SUBSCRIPTION_ID`, and others) to a literal `-` character — re-set all of them directly and verified via length checks.
- GitHub's newer "immutable ID" OIDC subject claim format didn't match the federated credential `azd pipeline config` created — added matching credentials for both `main` and `pull_request`.
- `azd`'s own environment state doesn't inherit subscription/location/principal-id from process env in a fresh CI job — now set explicitly via `azd env new --subscription --location` and `azd env set AZURE_PRINCIPAL_ID`.
- `Contributor` doesn't include `Microsoft.Authorization/roleAssignments/write` — granted `Role Based Access Control Administrator` scoped to the app's resource group only.
- `azd deploy` needed `AZURE_CONTAINER_REGISTRY_ENDPOINT` set explicitly (not a Bicep output it reads automatically).
- Dataverse embeds a stale `<MissingDependencies>` snapshot in exported solutions that replays as a real check on cold-start import — cleared per the documented Microsoft workaround.
- The Admin Console app module's SiteMap was never added to the solution as its own component — only worked in dev by coincidence (the sitemap already existed there outside the package). Added via the Dataverse `AddSolutionComponent` action.

Full diagnosis chain for all of the above in [ADR-0013](docs/adr/0013-combined-release-process.md) and `PROJECT_JOURNAL.md`.

## [Milestone 8] — 2026-08-07 — Observability & Ops

### Added
- `infra/modules/monitoring.bicep`: two Azure Monitor metric alerts (Container App restart-spike, APIM failed-requests) plus an email action group, deployed and verified live.
- `docs/troubleshooting.md`: symptom-indexed reference across every real issue this project has hit, linking back to the relevant ADR/journal entry rather than duplicating it.
- `docs/observability.md`: ties together the new alerts and a review of Power Platform's native analytics — no custom tooling needed there, the native surfaces (Copilot Studio Analytics, Dataverse auditing) already cover this project's needs.
- The **Microsoft Dataverse** connector ("Add a new row") wired to the parent agent, Maker authentication mode, silently logging a Conversation Audit Log entry after every response.

### Fixed
- The restart-spike alert false-fired within hours of deployment — `RestartCount` is a cumulative gauge, not a per-interval delta, and the alert's `Total` (Sum) aggregation summed three consecutive readings of the same steady value into an artificial spike with zero real restarts in the window. Root-caused by pulling the raw metric values directly rather than trusting the alert's own interpretation; fixed by switching to `Maximum` aggregation.
- Every Conversation Audit Log write failed with `400`: the Milestone 7 orphaned self-referencing column, previously assessed as harmless, turned out to break every create request through the generic Dataverse connector (a present-but-null navigation property is invalid OData). Fixed by deleting the column's owning relationship (the column itself stayed undeletable directly) after clearing two dependencies surfaced by Dataverse's own Dependencies panel — a stale system view and an auto-generated "AI Skill Config" object from the Dataverse intelligence setting enabled in Milestone 5. ADR-0012 corrected.

### Known gaps
- Application Insights has been provisioned since Milestone 0 but was never wired into the API's application code — real APM/tracing would need an SDK change out of scope for this milestone's alerting-focused needs. Documented, not silently left.

## [Milestone 7] — 2026-08-06 — Business Data & Admin

### Added
- ADR-0012: Dataverse tables for agent configuration and audit logging — built once via the maker portal (no reliable CLI surface for new-entity metadata authoring), captured as a solution for reproducibility. Closes the loop on Milestone 1's deferred Dataverse security roles.
- `Agent Configuration` and `Conversation Audit Log` Dataverse tables, plus **Admin**, **Agent.User**, and **Auditor** security roles scoped to them — Agent.User reads its own audit entries only (row-level security), Auditor reads everyone's, mirroring the Entra App Roles from Milestone 1.
- **Platform Admin Console**, a Power Apps model-driven app over both tables.
- `power-platform/solutions/business-data/`: the whole schema captured as a Dataverse solution, plus `scripts/deploy-business-data-solution.ps1` (pack + import), tested end-to-end against the live environment.

### Fixed
- A Lookup column's "Related table" search couldn't find the built-in User table while creating it inline during table creation, and left behind an undeletable self-referencing Lookup column on the first attempt — worked around by creating a second, correctly-configured lookup (`UserLookup`) rather than fighting the broken one further; it worked normally on retry.
- The table's default form still referenced the broken column after the working one was added (new columns don't auto-appear on existing forms) — fixed with a manual form edit, re-captured into the solution.
- The exported solution's `Solution.xml` baked the live org ID into the publisher's auto-generated name fields — caught by the routine sensitive-content sweep, redacted to a plain alphanumeric placeholder before committing.

## [Milestone 6] — 2026-08-06 — Workflow Automation & Enterprise Integration

### Added
- ADR-0011: Enterprise Integration Agent uses native Microsoft Teams and Office 365 Outlook connectors rather than custom Graph-calling code — same native-over-pro-code reasoning as ADR-0009/0010. Separated "enterprise integration" (this milestone) from "workflow automation" (Power Automate/Logic Apps/Service Bus — evaluated, not implemented, nothing here needs an async process).
- Microsoft Teams ("List channels") and Office 365 Outlook ("SendEmailV2") Tools on the Enterprise Integration Agent, both set to per-user (**User**, not Maker) authentication — consistent with the delegated-auth principle held since Milestone 1.

### Known limitations
- Teams testing blocked by the same tenant-origin Teams sign-in issue documented in Milestones 3/4 (`We couldn't find a Microsoft account`) — not re-investigated, already a known and accepted limitation.
- Outlook's `SendEmailV2` action never completes despite extensive troubleshooting across every angle available: the permission card doesn't render at all on three surfaces (maker Preview in Firefox and Edge, End user preview toggle, a self-hosted Web app embed); switching authentication mode from User to Maker made no difference; checked the action's "From (Send as)" parameter for a plausible Exchange-permission explanation (ruled out); testing directly on the child agent's own Preview finally got the permission card to render with visible Allow/Deny buttons — but clicking Allow still didn't complete the grant, with the connector re-prompting for consent twice more even after retrying. The agent's own behavior was correct throughout (identifies the requirement, refuses to fake success, reports clean failures), confirming the integration itself is correctly wired; the failure is specifically that the OAuth consent grant for this connection doesn't persist, a genuine platform reliability issue investigated from every practical angle, not a configuration gap on this project's side. Third distinct Copilot Studio consent/permission UI issue this project has hit (following the connector popup storm in Milestone 3 and the Dataverse knowledge-source panel hang in Milestone 5).

## [Milestone 5] — 2026-08-06 — Knowledge Retrieval (RAG)

### Added
- ADR-0010: RAG via Azure AI Search's native indexer (no custom Functions ingestion) and Copilot Studio's native knowledge connection — corpus is this project's own documentation (~20,000 words, zero copyright risk, self-referential).
- `infra/modules/knowledge-storage.bicep`, `infra/modules/ai-search.bicep`: Blob storage + Free-tier AI Search service, deployed and live.
- Embedding model deployment (`text-embedding-3-small`, `GlobalStandard`) added to the existing Azure OpenAI resource.

### Fixed
- Cognitive Services rejected concurrent deployments on sibling resources under the same account (`RequestConflict`) — fixed with an explicit `dependsOn` between the chat and embedding model deployments.
- Free-tier AI Search's Storage connection initially assumed to require a key per Microsoft's docs — actually just needed the Search service's managed identity granted `Storage Blob Data Reader`, no key needed after all. ADR-0010 corrected in place.
- Embedding skill failed with `AuthenticationTypeDisabled` (trying key-based auth against an OpenAI resource with `disableLocalAuth: true`) — fixed by clearing the skillset's `apiKey` field via direct REST calls, falling back to the Search service's system-assigned identity.
- A 403 on the Search data-plane REST API that looked exactly like slow RBAC propagation (waited 50+ minutes) turned out to be a hard configuration gap instead — the service's `authOptions` defaulted to `apiKeyOnly`, making any RBAC grant permanently ineffective regardless of wait time. Fixed by setting `authOptions.aadOrApiKey` explicitly in Bicep.

### Verified
- AI Search indexer succeeded: 154/154 documents, 165 chunks indexed, confirmed live via the Search REST API and portal document count.

### Known limitations
- Copilot Studio can't consume the AI Search index directly: "Add knowledge → Azure AI Search" doesn't exist for agents on the GitHub Copilot harness (Standard-harness-only, no migration path between harnesses for an existing agent). Not pursued given the cost of rebuilding Milestones 3-4's Copilot Studio work for one feature — this integration path remains permanently blocked, though the AI Search infrastructure itself is real and independently verified.

### Corrected (see PROJECT_JOURNAL.md, Milestone 5)
- The fallback direct file-upload knowledge source (a separate Dataverse-native pipeline, gated behind a Preview-labeled "Dataverse intelligence" environment setting) was originally documented as stuck after indexing sat "In progress" for several hours. It wasn't — it completed and reached "Ready" after several more hours, and a real test query returned an accurate answer pulled from the actual document content. The feature works; it's just far slower than Microsoft's documented "several minutes" for a 16-file batch. **The Knowledge Agent's actual capability — this milestone's real goal — is achieved via this path.** The maker Preview's per-file status panel hanging the browser (both Firefox and Edge) remains a real, separate client-side issue.

## [Milestone 4] — 2026-08-05 — Multi-Agent Coordination

### Added
- ADR-0009: Copilot Studio Connected Agents chosen over pro-code Semantic Kernel routing for multi-agent coordination — explicitly rejected the lower-friction pro-code option because this project exists to demonstrate Copilot Studio competency specifically, and Connected Agents can do the job.
- Two Connected Agents wired to the Milestone 3 parent agent: **Knowledge Agent** (placeholder pending Milestone 5's real RAG) and **Enterprise Integration Agent** (placeholder pending Milestone 6's real Graph actions), each with routing-critical descriptions.
- Parent agent's instructions rewritten to define the full orchestration pattern explicitly (routing criteria, invoke → wait → combine → respond, subagents never reply directly) per Microsoft's documented multi-agent best practices, rather than a vague "use child agents when relevant."

### Verified
- Four targeted test messages confirm correct routing: knowledge-domain → Knowledge Agent, enterprise-integration → Enterprise Integration Agent, general → the existing Milestone 3 platform tool, domain-mismatch (weather) → graceful fallthrough to the general tool rather than getting stuck.
- One recurrence of the Milestone 3 tool-call timeout during testing — isolated to a single Container App restart (confirmed via Log Analytics: one restart in 2 hours, requests immediately before/after both succeeded). `minReplicas: 1` eliminates the *guaranteed* cold start after idle periods; it doesn't guarantee zero restarts ever, since Container Apps can still recycle a replica for platform-level reasons. Copilot Studio's own retry logic recovered automatically. Documented as a known residual limitation, not chased further given it self-heals.

## [Milestone 3] — 2026-08-05 — Copilot Studio Agent

### Added
- ADR-0006: Copilot Studio custom connector uses managed identity + federated credential instead of a client secret — the connector calls the API as the signed-in user (preserving Milestone 1's per-user RBAC) without introducing this project's first stored secret. Reuses the existing API app registration. **Superseded by ADR-0007 below.**
- ADR-0007: managed identity turned out to be an unreliable preview feature (undocumented, no CLI surface, and one portal attempt deleted the connector outright). Falls back to standard client-secret OAuth, secret stored in Key Vault rather than only ever existing as a value pasted into a portal field — this project's first stored secret, and a documented exception to its zero-secrets posture.
- ADR-0008: Copilot Studio authorization spans four independent, portal-only permission systems (Entra security group, per-user license/trial, Azure pay-as-you-go billing, Microsoft 365 billing-account role) — documents all four, and the finding that the free trial alone was likely sufficient for what this milestone actually needed.
- `power-platform/solutions/connectors/platform-api/`: custom connector definition (Swagger 2.0 + OAuth AAD properties), templated with placeholders, created live via `pac connector create`.
- `scripts/setup-copilot-connector.ps1`: generates the real connector files from templates and creates or updates the connector (idempotent).
- "Enterprise Multi-Agent Platform" agent authored in Copilot Studio, with the connector wired in as a Tool (`Ask the platform agent a question`) and instructions directing the model to always route through it rather than answer from its own knowledge.

### Fixed
- Connector's OAuth resource fields (`AzureActiveDirectoryResourceId`, `resourceUri`) used the App ID URI form (`api://<client-id>`), which Entra rejects for self-referential token requests (`AADSTS90009`) when client and resource are the same app. Changed to the bare client-id GUID — the same underlying platform behavior Milestone 1 already documented from a different angle.
- Reusing the API app as its own OAuth client also needs its own `access_as_user` scope explicitly listed under its own API permissions (`AADSTS650057` otherwise) — exposing a scope isn't the same as being permitted to request it against yourself. Folded into `scripts/setup-entra-app.ps1` (idempotent) rather than left as a one-off CLI fix.
- Apps created via `az ad app create` don't get the Microsoft Graph `User.Read` ("Sign in and read user profile") delegated permission that portal-created apps receive by default — without it, sign-in fails outright (`AADSTS90008`). Added and granted, also folded into `scripts/setup-entra-app.ps1`.
- The app registration had no reply URL at all (`AADSTS500113`) — it was created purely as an API resource, never as an OAuth client. Registered Power Platform's bare custom-connector OAuth broker endpoint, read-merge-write to preserve room for other redirect URIs.
- The bare endpoint alone wasn't sufficient (`AADSTS50011`) — Power Platform actually requires a connector-specific redirect URL (unique suffix per connector, confirmed via Microsoft's docs), copied from the connector's Security tab or, in this case, echoed back by the mismatch error itself. Registered alongside the bare one; stored as `COPILOT_CONNECTOR_REDIRECT_URI` in `.env` (not hardcoded) since it's an environment-specific value. `scripts/setup-entra-app.ps1` now registers both.
- Past the redirect fix, token exchange failed with `AADSTS7000215: Invalid client secret provided` — expected, since no secret had ever been configured (managed identity was the plan). See ADR-0007: switched to client-secret auth instead after the managed-identity portal flow proved unreliable.
- The connector's Security-tab form was showing tenant ID and scope as unset even though `pac connector update` had set them correctly underlying — filled in from the real (gitignored) `apiProperties.json` rather than guessed, since the form doesn't roundtrip everything from the CLI-pushed definition.
- First tool-call test failed with a 30-second `ConnectorTimeout` — Copilot Studio's tool-call timeout is shorter than a cold start (image pull + Semantic Kernel init + first Azure OpenAI call) on a scale-to-zero Container App. Not configurable via the connector's Swagger definition (checked). Fixed by raising `minReplicas` from 0 to 1 (`infra/modules/container-app-api.bicep`) — a small, confirmed-negligible ongoing cost traded for eliminating the cold start entirely.
- Copilot Studio agent saves/creation failed tenant-wide with `permission to create agents / User license not found` — required an Entra security group (`Copilot Studio authors` tenant setting), a Copilot Studio trial license, and (to unblock the trial checkout button itself) fixing a missing Microsoft 365 billing-account address field. See ADR-0008.
- Demo Website publish channel requires disabling the agent's own authentication entirely — structurally incompatible with this project's per-user delegated-auth design, not pursued as a channel.
- Teams channel sign-in currently fails (`We couldn't find a Microsoft account`) — likely the same personal-account-derived-tenant root cause as ADR-0004, not a new issue. Not required for any subsequent milestone; deferred.

### Verified
- A real Connection completes interactive AAD sign-in successfully against the deployed connector under client-secret auth — full chain confirmed end-to-end (redirect URI, Graph consent, self-referencing scope, token exchange).
- Re-attempted the managed-identity switch once reliability was in hand as a fallback: it took the switch without deleting the connector this time, but silently reverted to requiring a client secret on revisiting the connector, with no action taken in between. Second distinct unsafe-failure mode from the same preview feature — documented in ADR-0007 as firsthand evidence, not just Microsoft's own "(Preview)" label.
- End-to-end in Copilot Studio's Preview pane: real user identity → connector's per-user delegated OAuth → platform API's Entra App Role check (Milestone 1's RBAC) → Semantic Kernel → real Azure OpenAI response. This is the actual architectural claim of this milestone, proven without needing a published, externally-reachable channel.

### Deferred (documented, not forgotten)
- Publishing to an externally-reachable channel (Teams once its sign-in issue clears, or a `Web app` embed) — not needed for any milestone through Milestone 9; may be revisited for a Milestone 10 demo recording.
- The Copilot Studio pay-as-you-go billing plan and the Contributor RBAC grant it required are left in place though likely unnecessary (ADR-0008) — full teardown (all project accounts, billing links, the temporary payment card) planned at project completion, not before.

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
