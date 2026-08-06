# Troubleshooting Guide

A symptom-indexed reference to real issues hit while building this platform. Each entry links
to the ADR or `PROJECT_JOURNAL.md` section with the full detail, root cause investigation, and
fix — this page exists to get you to the right place fast, not to duplicate that content.

## Local tooling (Windows / Git Bash)

| Symptom | Cause | Fix |
|---|---|---|
| `az` command with a `/subscriptions/...` argument fails with `MissingSubscription` or a nonsensical path error | Git Bash's MSYS layer rewrites leading-slash arguments as Windows paths before `az` ever sees them | Prefix the command with `MSYS_NO_PATHCONV=1` |
| `azd provision` or `azd deploy` fails with a Docker error, even for a pure infra change | This `azd` version validates the full pipeline's required tools upfront, including Docker, regardless of whether the specific command needs it | Start Docker Desktop, or deploy directly via `az deployment sub create --template-file infra/main.bicep ...` to bypass `azd`'s tool-validation gate entirely (`PROJECT_JOURNAL.md`, Milestone 4/5) |
| A PowerShell command with a `<placeholder>`-style argument fails with "The syntax of the command is incorrect" | PowerShell treats `<` and `>` as redirection operators, not literal characters | Substitute the real value instead of a placeholder, or quote/escape appropriately |

## Azure infrastructure

| Symptom | Cause | Fix |
|---|---|---|
| A model appears in `az cognitiveservices model list` but deployment fails with `ServiceModelDeprecating` | Catalog presence doesn't imply deployability | Check the `lifecycleStatus` field, not just presence — see ADR-0005 |
| A model/SKU combination shows 0 quota by default | Quota is per-SKU (`GlobalStandard` vs `DataZoneStandard`), not just per-model | `az cognitiveservices usage list --location <region>` to check actual available quota before choosing a SKU |
| Two sibling `Microsoft.CognitiveServices/accounts/deployments` resources in the same Bicep deployment fail with `RequestConflict` | Cognitive Services rejects concurrent operations on deployments under the same parent account | Add an explicit `dependsOn` to force sequential deployment (`infra/modules/ai.bicep`) |
| A Container App's `registries` block fails on first provision | Chicken-and-egg: the block references a managed identity's `AcrPull` role that doesn't exist yet in the same deployment | Omit `registries` on first provision (placeholder image must be public), add it back once RBAC has settled |
| APIM `method: '*'` operation silently matches nothing, every request 404s | Not a real wildcard in APIM's policy model | Define one explicit operation per HTTP method |
| A 403 on an Azure resource's data-plane REST API persists no matter how long you wait after granting RBAC | The resource's own `authOptions` may default to key-only auth, making RBAC grants silently ineffective regardless of propagation time (hit on Azure AI Search — ADR-0010) | Check the resource's own auth-mode setting directly, don't assume it's just propagation lag |

## Entra ID (self-referencing app registrations)

The pattern where an app registration acts as both OAuth client and protected resource (used
by the Copilot Studio connector, ADR-0006/0007) has several sharp edges, all fixed
idempotently in `scripts/setup-entra-app.ps1`:

| Error | Cause | Fix |
|---|---|---|
| `AADSTS90009` | Resource expressed as `api://<client-id>` instead of the bare GUID, for a self-referential token request | Use the bare client-id GUID |
| `AADSTS650057` | App exposes a scope but doesn't list it under its own API permissions | `az ad app permission add` + `grant`, pointing the app at itself |
| `AADSTS90008` | `az ad app create` doesn't grant Microsoft Graph `User.Read` the way portal-created apps do | Add and grant `User.Read` explicitly |
| `AADSTS500113` | App registration has no reply URL at all | Register Power Platform's OAuth broker redirect URI |
| `AADSTS50011` | The bare redirect URI isn't enough — Power Platform actually needs a connector-specific one (unique suffix per connector) | Copy the exact URI from the connector's Security tab (or the mismatch error itself) and register it too |
| `AADSTS7000215` | Client secret invalid/missing | See "Copilot Studio connector auth," below |

## Copilot Studio: licensing and billing

Four independent, unrelated permission systems gate Copilot Studio access — see ADR-0008 for
the full story. In order of likely relevance if `permission to create agents` or a publish
error shows up:

1. **Copilot Studio authors** Entra security group (Power Platform admin center → Tenant settings).
2. **Copilot Studio license/trial** (Microsoft 365 admin center) — covers create + test, not publish.
3. **Pay-as-you-go billing** linked to an Azure subscription — needed for publishing specifically.
4. **Microsoft 365 billing-account role** — needed just to complete a trial checkout; manifests as a permanently-disabled "Try now" button with no explicit error, not an obvious licensing message.

## Copilot Studio: connector auth

| Symptom | Cause | Fix |
|---|---|---|
| Managed-identity connector auth deletes the connector on failure, or silently reverts to requiring a client secret on revisit | "Managed Identity (Preview)" is an unreliable preview feature (confirmed twice, independently — ADR-0007) | Use client-secret auth instead, secret stored in Key Vault |
| Connector's Security tab isn't visible anywhere | You're likely looking at the **Connection** creation dialog, a different screen from the connector's own **Edit** view (pencil icon on the Custom Connectors list) | Navigate to the connector's Edit screen specifically |
| `Add knowledge → Azure AI Search` doesn't appear as an option | Standard-harness-only feature; not available for agents on the GitHub Copilot harness, with no migration path between harnesses (ADR-0010) | Use a different knowledge source (e.g. direct file upload), or accept as a documented limitation |

## Copilot Studio: consent/permission UI reliability

A recurring pattern across three independent features this project hit (connector consent,
Dataverse knowledge-source status, Outlook action permission) — worth checking your specific
symptom against this list before assuming misconfiguration:

- A connector's "Manage your connections" OAuth flow opens dozens of blank popups instead of one — Firefox's popup blocker catches this; not fixable from this project's side, try Edge/Chrome.
- A Dataverse-backed knowledge source's per-file status detail panel hangs the entire browser (reproduced in both Firefox and Edge) — avoid opening it; check status from the list view instead, or wait it out.
- A tool-call's permission consent card is described in the response text ("select Allow on the permission card") but never actually renders, across the maker Preview, End user preview, and a self-hosted Web app embed — the underlying integration is likely correctly wired (check whether the agent reports a clean decline rather than pretending success); this is a UI rendering bug, not something to keep debugging across more surfaces.

## Dataverse

| Symptom | Cause | Fix |
|---|---|---|
| A Lookup column's "Related table" search can't find a built-in table (e.g. `systemuser`/User) | Appears to be a transient UI glitch — reproduced once, worked normally on retry | Finish the column/table without the lookup, retry adding it as a separate step |
| A Lookup column can't be deleted ("has dependencies") | Data Type and Related Table are immutable after creation by design; a wrong related-table selection can't be fixed in place | Leave it unused, create a correctly-configured column with a different name |
| A newly-added column doesn't show up on an existing table's form | Forms are a snapshot at creation time; new columns don't auto-appear | Edit the form manually and add the field |
| `pac solution export`/other tenant-scoped `pac` commands fail with an MFA requirement, even though the same profile works for environment-scoped commands | Tenant-admin-scoped operations need a stronger auth context | Re-run `pac auth create` interactively (needs a real browser/device-code sign-in, can't be scripted headlessly) |
| An exported solution's `Solution.xml` contains your real tenant/org ID | Dataverse derives the publisher's `UniqueName` from its display name, which may include environment-specific text | Redact before committing (publisher unique names only allow `[A-Za-z0-9_]`, no angle-bracket placeholders) |

## General principle

Every entry above was found by checking the actual current state (a resource's config, a
service's own auth settings, the real error text) rather than assuming based on documentation
or a plausible-sounding guess — see `PROJECT_JOURNAL.md` for the specific investigations. When
in doubt, that's the pattern to repeat: verify directly before acting.
