# Manual Setup

This document lists **only** the actions that cannot reasonably be automated for this project, and why. Everything else is scripted via Bicep, `azd`, `pac`, or GitHub Actions. If a step below becomes automatable later (tooling catches up), it should be removed from here and moved into the relevant pipeline.

## 1. Azure subscription + an organizational user in the same tenant for Power Platform (see ADR-0004)

**Manual because:** account/tenant creation and billing enrollment happen outside any CLI's authority — there is no API that creates an Azure subscription from nothing. Separately, Power Platform/Dataverse/Copilot Studio reject personal Microsoft accounts (`AADSTS500200`) — they require a "work or school" organizational account. (We first tried a second tenant via the Microsoft 365 Developer Program — ADR-0003 — but its instant-sandbox eligibility check rejected the account with no appeal path. ADR-0004 supersedes that with the approach below.)

**Action:**
1. Azure subscription: the free Azure account (personal Microsoft account) already provides one, with its own default directory/tenant (`740c395a-...`).
2. In the Azure portal, signed in as that personal account (currently Global Admin of the tenant), go to **Microsoft Entra ID → Users → New user → Create new user**. Create an organizational user (e.g. `pp-admin@<tenant>.onmicrosoft.com` — the exact `.onmicrosoft.com` domain is shown on the Entra ID Overview page) and assign it the **Global Administrator** role.
3. Sign in as that new user at the **[Power Apps Developer Plan](https://make.powerapps.com/developerplan)** signup — this provisions a free, indefinite, non-production Dataverse environment in the *same* tenant, with no credit card and no eligibility gate (a different, more permissive signup flow than the M365 Developer Program).
4. Use this same new user for `pac auth create` and Copilot Studio going forward.

**Repeated for Milestone 9:** the same pattern (new organizational user → Power Apps
Developer Plan signup) was used again to provision a second, free environment for real
dev→test promotion testing — see item 3's "Repeated for Milestone 9" note and
[ADR-0013](docs/adr/0013-combined-release-process.md).

## 2. Initial interactive logins

**Manual because:** the first credential handshake for each CLI requires an interactive browser/device-code flow; there is no bootstrap secret to script this from a clean machine.

**Action (one-time, per machine):**
```powershell
az login                              # sign in with the personal-account-derived Azure tenant
azd auth login                        # same tenant as az login
pac auth create --name dev            # MUST use the new organizational user (item 1, step 2) — a personal account fails with AADSTS500200
gh auth login   # already done for this environment
```

## 3. Power Platform environment + Dataverse database provisioning and licensing

**Manual because:** creating a new Power Platform environment with a Dataverse database can be scripted (Admin PowerShell module or `pac admin create`) *if* the signed-in account already has tenant admin rights and the tenant already has spare Power Platform/Dataverse capacity — but acquiring that capacity/licensing (or a trial) in the first place is a portal/licensing-admin action, not a CLI one.

**Action:** the Power Apps Developer Plan signup (item 1, step 3) provisions this automatically. Confirm it via [admin.powerplatform.microsoft.com](https://admin.powerplatform.microsoft.com) signed in as the new organizational user, then record its environment URL in `.env` (`POWER_PLATFORM_ENVIRONMENT_URL`) for use by `pac` and the ALM pipeline.

**Known hiccup:** this tenant (Switzerland-based) is in the rollout group for Microsoft's newer "macro region geography" environment-creation requirement (also applies to Canada/Norway/France tenants). The `pac admin create --region <name>` CLI and the `make.preview.powerapps.com` quick-create panel both rejected every region string tried (`macroRegion '...' is not valid` / `macroRegion must be specified`) — the valid macro-region tokens aren't documented anywhere. **Fix:** use the full wizard at [admin.powerplatform.microsoft.com](https://admin.powerplatform.microsoft.com) → Environments → **+ New** (not the CLI, not the preview-portal quick panel) and pick a value from its **Region** dropdown directly — that dropdown is populated dynamically with the tenant's actual valid options and resolves correctly server-side.

**Repeated for Milestone 9 (test environment):** provisioning a second environment for real
dev→test promotion followed a slightly different sequence — the admin center wizard's **+
New** created the environment itself without Dataverse attached (`Dataverse: No` in the
environment list), requiring a separate, explicit **Add Dataverse database** action
afterward (same wizard, environment details page) to actually provision the database. Both
steps are portal-only either way; recorded here since the single-step Developer Plan signup
flow (item 1) doesn't always produce a Dataverse-attached environment on the first try.

## 4. Microsoft Entra ID admin consent

**Manual because:** app registrations and their requested API permissions (Microsoft Graph delegated scopes, custom App Roles) can be created via `az ad app create`/Microsoft Graph API, but granting **tenant admin consent** for those permissions is a deliberate security gate that Microsoft requires as an interactive portal action (or `az ad app permission admin-consent`, which itself still requires an account with Global/Privileged Role Administrator rights present at run time).

**Action:** after the app registration is scripted (Milestone 1), a tenant admin consents to the requested permissions in the Entra admin center (App registrations → API permissions → Grant admin consent).

## 5. Copilot Studio authoring steps

**Manual because:** as of this writing, creating a Copilot Studio agent, configuring generative orchestration/topics, wiring a custom action to the custom-engine-agent backend, and publishing to a channel (Teams) are maker-portal-driven experiences — Microsoft does not yet expose a CLI/ARM/Bicep surface for authoring Copilot Studio agent content (only export/import of an already-authored agent as a solution is scriptable via `pac`).

**Action:** author the agent in [copilotstudio.microsoft.com](https://copilotstudio.microsoft.com) (Milestone 3), then export it as a solution so subsequent environment promotion is handled by the Power Platform ALM pipeline, not by repeating manual authoring.

**Resolved as follows:** the agent (and its Connected Agents) has no registered Dataverse `componenttype` at all — the only supported way to add it to a solution is the maker portal's own Solutions UI ("Add existing" → Copilot), a manual, one-time step per solution, not scriptable. Once added, the solution exports and promotes through `power-platform-deploy.yml` automatically like any other. See [ADR-0015](docs/adr/0015-copilot-studio-agent-promotion.md) for the full path, including two further Dataverse/Copilot Studio platform limitations hit along the way (custom connectors need their own dedicated solution; a custom connector's internal ID — and so any connection reference naming it — is environment-specific and can't survive an environment move automatically, needing a one-time manual reconnect per environment).

## 6. Azure AI Foundry / Azure OpenAI model access and quota

**Manual because:** the Azure resource and project are Bicep-deployable, but specific model deployments (e.g., GPT-4o) can be subject to regional quota limits or access approval that varies by subscription and is granted through the Azure portal/quota request form, not a deployment template.

**Action:** confirm model availability/quota in the target region before running the Bicep deployment that requests a model deployment; request additional quota via the Azure portal if the default is insufficient.

**Resolved for Milestone 2 as follows:** two real gates hit in practice, both worth checking before assuming a model deployment will succeed:
1. `az cognitiveservices model list --location <region>` can list a model/version that's actually in `lifecycleStatus: Deprecating` and rejected for new deployments (`gpt-4.1-mini` version `2025-04-14` hit this) — check `lifecycleStatus`, not just presence in the list.
2. Even a `GenerallyAvailable` model can have **zero default quota** on a specific SKU. Check with `az cognitiveservices usage list --location <region>` before deploying — e.g. this subscription had 0 quota for `gpt-5-mini` under `DataZoneStandard` (EU data residency) but 500 under `GlobalStandard`. If your compliance requirements need `DataZoneStandard` specifically and the quota is 0, that's the one genuinely manual step here: request a quota increase via the Azure portal (Quotas → Azure OpenAI).

## 7. GitHub↔Azure OIDC trust verification

**Manual because:** `azd pipeline config` automates creation of the federated credential and GitHub secrets/variables, but a final human check that the federated credential's subject claim matches the actual repository/environment/branch is worth doing once, since a mismatch fails silently as an auth error during CI rather than at setup time.

**Action:** after `azd pipeline config` runs, verify the federated credential subject in the Entra app registration matches `repo:<org>/<repo>:ref:refs/heads/main` (or the configured environment).

**Resolved for Milestone 9 as follows:** the check above wasn't just precautionary — GitHub now presents OIDC subject claims using an "immutable ID" format (`repo:OWNER@ownerId/REPO@repoId:ref:refs/heads/main`) that didn't match what `azd pipeline config` created, failing with `AADSTS700213: No matching federated identity record found`. Fixed by adding a second federated credential per trigger type (`main` ref, `pull_request`) using the immutable-ID subject — both formats coexist fine on the same identity. See [ADR-0013](docs/adr/0013-combined-release-process.md) for the full chain (this was one of six distinct root causes hit standing up the pipeline, not the only one).

## 8. Container image builds require a local Docker daemon

**Manual because:** `azd deploy`'s remote-build option (ACR Tasks, server-side build with no local Docker needed) is disabled on this subscription entirely — `TasksOperationsNotAllowed`, a platform restriction with no config workaround (Microsoft's own suggestion is to file a support request). Local Docker build is the fallback, which needs Docker Desktop actually running, not just installed.

**Action:** before `azd deploy`, ensure Docker Desktop is running (`docker info` succeeds). CI runners (GitHub-hosted) have Docker available by default, so this is a local-machine-only concern, not a CI blocker.

## 9. Copilot Studio connector: paste the client secret into the Security tab

**Manual because:** ADR-0006's managed-identity plan (no stored secret at all) turned out to depend on a "Managed Identity (Preview)" portal feature that wasn't reliably reachable — see [ADR-0007](docs/adr/0007-copilot-connector-client-secret.md), which falls back to standard client-secret OAuth instead. Confirmed against Microsoft's own certified-connector examples that the `aad` identity provider's connector definition has no `clientSecret` field at all — the secret has always been a value typed into the connector's Security tab in the maker portal, never something `pac connector create`/`update` can set from a file.

**Action:**
1. Retrieve the secret yourself, locally — never paste it into chat or a file: `az keyvault secret show --vault-name <your-key-vault-name> --name copilot-connector-client-secret --query value -o tsv` (find the vault name with `az keyvault list -o table`; it's the one from Milestone 0's `azd provision`)
2. In [make.powerapps.com](https://make.powerapps.com) (signed in as the Power Platform organizational user) → **Custom connectors** → open "Multi-Agent Platform API" → **Security** tab.
3. Identity Provider: **Azure Active Directory**. Client ID is already set from `pac connector update`; paste the retrieved value into **Client secret**. Save.
4. Create a **Connection** from the connector (one-time interactive sign-in) to confirm the trust works end-to-end before wiring it into Copilot Studio.
5. The secret expires after 1 year (`az ad app credential list --id <api-app-id>` to check dates) — rotate by generating a new one, updating the Key Vault secret, and repeating steps 1–3.

## 10. Copilot Studio licensing (authoring + trial + billing account)

**Manual because:** Copilot Studio authorization spans four independent, portal-only permission systems — an Entra security group, a per-user license/trial, Azure billing linkage, and a separate Microsoft 365 billing-account role — none scriptable end-to-end, and none documented together anywhere. See [ADR-0008](docs/adr/0008-copilot-studio-licensing.md) for the full story and why the billing-plan piece specifically may turn out to be unnecessary.

**Action:**
1. Create the Entra security group and add the authoring user (scriptable — `az ad group create` + `az ad group member add`), then in [Power Platform admin center](https://admin.powerplatform.microsoft.com/) → **Manage → Tenant settings → Copilot Studio authors**, assign that group. Portal-only for the assignment step itself.
2. If a "Try now" / trial checkout button stays permanently disabled with no clear error, check **Microsoft 365 admin center → Billing → Billing accounts** for a missing required field (e.g. address) — it silently blocks all purchases/trial activations, not just Copilot Studio.
3. Search "**Copilot Studio Trial**" in the Microsoft 365 admin center Marketplace (top search bar, not the left-nav "Your products" list, which can land on the wrong/paid listing) and activate the free trial for the authoring user — sufficient for creating and testing agents via the Preview pane.
4. Only if publishing is actually needed: create a pay-as-you-go billing plan (Power Platform admin center → Licensing → Copilot Studio → **New billing plan**), scoped to the **Copilot Studio** meter specifically (not Dataverse/Power Apps/Power Automate). This requires the authoring account to have **Contributor** on the target Azure subscription (`az role assignment create --role Contributor`) — it won't otherwise, per ADR-0004's two-account setup.
5. Sign out of Copilot Studio and back in after each of the above — group/license/billing changes don't take effect in an existing session.

Anything not listed here — resource provisioning, RBAC assignments, CI/CD wiring, Power Platform solution deployment, cost budgets — is automated. This file will be updated immediately if another genuinely manual step is discovered during implementation.
