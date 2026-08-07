# Cost Analysis

**Budget policy (revised — see [ADR-0002](adr/0002-cost-policy.md)): prefer Azure-native services over free-alternative workarounds, within a 30-day build window covered by the Azure free account's $200 credit, with up to $20 out-of-pocket accepted for anything the credit doesn't reach.** The original $0-at-all-costs framing (favoring GitHub Container Registry over ACR, etc.) is superseded — see ADR-0002 for the reasoning.

Pricing below was researched August 2026 and changes over time — re-verify against the [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/) and each service's pricing page before relying on it for anything beyond this portfolio project.

## Free credits and entitlements this project stacks

| Source | What it covers | Duration |
|---|---|---|
| Azure free account | $200 credit (first 30 days) + 12 months of free monthly amounts of popular services + 40+ always-free services | One-time per new account/tenant |
| Power Apps Developer Plan | Free Dataverse environment (2 GB storage, 3 environments), Power Apps, Power Automate, standard connectors — non-production only | Indefinite (dev/test use) |
| Copilot Studio | Building and testing agents (in-context Agent Builder / trial) is free; only *publishing and running agents at scale* consumes paid message credits | Indefinite for build/test |
| GitHub Actions | 2,000 free Linux minutes/month on a private repo, **unlimited on a public repo** | Ongoing |
| Microsoft Entra ID | App registrations, RBAC (App Roles), free tier — no P1/P2 needed for this project | Ongoing |

The $200 Azure credit is expected to cover essentially all Azure spend across the 30-day build window. The $20 out-of-pocket ceiling exists for anything billed outside Azure subscription credit — mainly Copilot Studio pay-as-you-go message credits, which are M365/Power Platform billing, not Azure billing.

## Per-resource breakdown

Final state as of Milestone 10. Several resources planned earlier (Functions, Service Bus,
Static Web Apps, Fabric, Purview) were evaluated per ADR-0001's Microsoft Platform Evaluation
principle and **not built** — a native Power Platform/Copilot Studio capability covered the
same need at each decision point (see ADR-0010, ADR-0011). Kept in the table below with their
actual disposition rather than removed, since "evaluated and not needed" is itself part of
this project's documented decision history.

| Resource | Status | Free allowance | Cost if kept in free tier | Notes |
|---|---|---|---|---|
| Resource Group (`rg-dev`) | Live (M0) | n/a | $0 | No charge for the container itself |
| Log Analytics workspace + App Insights | Live (M0) | ~5 GB ingestion/month free, then ~$2.30/GB | $0 at low volume | App Insights was never actually wired into the API's application code — provisioned but not emitting telemetry, a real documented gap (`docs/observability.md`) |
| Key Vault | Live (M0) | Pay-per-10k-operations (~$0.03/10k) | ~$0 (pennies) | Holds the Copilot Studio connector secret and the Power Platform pipeline service principal's secret |
| API Management (Consumption tier) | Live (M0), wired to the API (M2) | 1,000,000 calls/month free, then ~$3.50/million | $0 | No idle/base cost — serverless, scales to zero |
| Azure Container Apps | Live (M2) | 180,000 vCPU-s + 360,000 GiB-s + 2,000,000 requests/month free | Small, ongoing | `minReplicas` raised from 0 to 1 in M3 — Copilot Studio's tool-call timeout (30s, not configurable) is shorter than a cold start, so scale-to-zero broke the integration outright. Accepted per ADR-0002 |
| Azure Container Registry (Basic) | Live (M0) | None | ~$5/month flat | Preferred over GitHub Container Registry — genuinely Azure-native (managed identity pull auth, no PAT). See ADR-0002 |
| Azure Functions | **Evaluated, not built** | — | $0 | RAG ingestion used AI Search's integrated vectorization skillset instead (ADR-0010); enterprise integration used Copilot Studio's native Graph connectors instead (ADR-0011) — neither needed a custom Functions backend |
| Azure AI Search (Free F0) | Live (M5) | 50 MB storage, 3 indexes, no SLA | $0 | RAG over the knowledge Blob container; sufficient for the demo corpus |
| Azure OpenAI (bare resource, per ADR-0005) | Live (M2) | No free tier; pay-per-token. `gpt-5-mini` (chat) + `text-embedding-3-small` (RAG), both `GlobalStandard` SKU | Usage-driven | Covered by the $200 credit at dev/demo volume |
| Azure AI Content Safety (F0) | Live (M10) | 5,000 text records/month free | $0 | ADR-0014 — input moderation on `/agent/chat` |
| Azure Service Bus | **Evaluated, not built** | — | $0 | This project's actual integration scenarios were all in-conversation agent actions, not async/background workflows — see ADR-0011 |
| Azure Static Web Apps | **Evaluated, not built** | — | $0 | `/apps/web` was never needed — Power Apps and Copilot Studio covered every user-facing surface this project required |
| Azure Cost Management | Live (M0) | Budgets/alerts | $0 | Guardrail against the credit running out mid-build |
| Power Platform environments + Dataverse (×2) | Live (M0, M9) | Developer Plan: free, non-production, one per environment | $0 | Dev (M0) + a second, free Developer Plan environment for real dev→test promotion (M9, ADR-0013) |
| Copilot Studio | Live (M3) | Free trial covers create + test-pane use fully; publishing needs paid capacity | $0 in practice | A pay-as-you-go billing plan was set up to unblock publishing (ADR-0008), left in place but not actively driving cost — nothing is published |
| Microsoft Graph connectors (Teams/Outlook/SharePoint/Planner) | Live (M6) | Included with Entra ID / M365 | $0 | Native Copilot Studio Tools, not custom Graph API calls (ADR-0011) |
| GitHub Actions CI/CD | Live (M0, expanded M9) | 2,000 free minutes/month (private) or unlimited (public) | $0 | Three workflows (`ci.yml`, `azure-dev.yml`, `power-platform-deploy.yml`); even full milestone CI stays inside the free allowance |
| Microsoft Fabric | **Evaluated, not built** | — | $0 | Azure Monitor workbooks + Power Platform's own native analytics (Copilot Studio Analytics, Dataverse auditing) covered this project's actual reporting need — see `docs/observability.md` |
| Microsoft Purview | **Evaluated, not built** | — | $0 | Documented evaluation only per ADR-0001; this project's data-governance surface (Dataverse security roles, Azure RBAC) didn't justify Purview's consumption-based cost at this scale |

## Operating model under the revised policy

1. **Azure-native by default.** Where an earlier draft of this doc suggested a free-tier workaround (GitHub Container Registry instead of ACR), the Azure-native service is now preferred — it's simpler to operate and the cost difference is noise against the credit.
2. **The credit is the primary budget, not a stretch goal.** Azure Cost Management is configured to alert well before the $200 credit is exhausted, not just to report spend after the fact.
3. **The $20 figure is a ceiling on non-Azure-billed spend**, not a target — realistic exposure there is a handful of Copilot Studio pay-as-you-go message credits at $0.01 each if a live demo needs them.
4. **Nothing changes about *when* things run** — Container Apps still scale to zero, Functions/Service Bus/APIM still have no idle cost. The policy shift is about which service to pick when there's a trade-off, not about running things 24/7.

## Actual spend at Milestone 10

Checked via `az consumption budget list` at the close of every milestone (per this project's
own practice, not just once at the end): spend has stayed at **$0.39 of the $180
guardrail** through Milestone 10, essentially flat since early in the build — the always-on
Container App (`minReplicas: 1`) is the only meaningfully recurring line item, and it's small
enough at this scale to not move the number. Every resource added in Milestones 5–10 (AI
Search, Content Safety, the second Dataverse environment, both CI/CD identities) is free-tier
by design, confirmed via this same budget check immediately after each was deployed.

## Budget configuration (live since Milestone 0)

- Azure Cost Management budget scoped to `rg-<env>`, monthly reset, alert thresholds at 50%/75%/90%/100% of $180 (90% of the $200 credit) — deployed via Bicep (`Microsoft.Consumption/budgets`, `infra/modules/budget.bicep`), confirmed live via `az consumption budget list`.
- Scoped to the resource group only, not the subscription — resources created outside `rg-dev` wouldn't be caught. Not a concern in practice since everything so far lives in that one resource group, but worth widening if that assumption ever changes.
- The Copilot Studio pay-as-you-go billing plan (M3) was deliberately scoped to `rg-dev` as its resource group, so — unlike the caveat below originally assumed — any actual Copilot Studio pay-as-you-go spend *does* flow through this same budget guardrail rather than needing separate monitoring. Still worth an occasional manual check of Copilot Studio's own Analytics tab, since the two systems don't share a single dashboard.

## Milestone 2 addition: model deployment gotchas

Provisioning the Azure OpenAI model deployment surfaced two things worth knowing before
picking a model/SKU combination, beyond just checking the price:

1. A model/version can appear in `az cognitiveservices model list` while being in
   `lifecycleStatus: Deprecating` and rejected for new deployments — check that field, not
   just presence in the catalog.
2. Default quota varies by SKU independently of price. This subscription had **0** default
   quota for `gpt-5-mini` under `DataZoneStandard` (EU-only data residency) but **500** under
   `GlobalStandard` (no processing-region guarantee) — same model, same per-token price,
   different quota. Used `GlobalStandard` since this portfolio project has no real
   compliance requirement forcing EU-only processing; see `manual-setup.md` #6 and
   [ADR-0005](adr/0005-azure-openai-over-ai-foundry.md) for the full trade-off.

## Caveats

- Pricing is regional and changes over time; the numbers above are directional, sourced August 2026.
- The Azure free-account $200 credit and 12-months-free window are one-time-per-account benefits.
- If this project were ever taken toward real production use (out of scope for the portfolio), essentially every line above would need re-costing at production scale (Standard/Premium APIM, Standard AI Search, provisioned throughput for the LLM, Power Apps per-user licensing, etc.) — see [`docs/deliverables/cost-estimate.md`](deliverables/cost-estimate.md) for that production-scale projection.
