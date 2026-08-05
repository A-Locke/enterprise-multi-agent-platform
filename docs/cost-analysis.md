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

| Resource | Status | Free allowance | Cost if kept in free tier | Notes |
|---|---|---|---|---|
| Resource Group | Live (M0) | n/a | $0 | No charge for the container itself |
| Log Analytics workspace + App Insights | Live (M0) | ~5 GB ingestion/month free, then ~$2.30/GB | $0 at low volume | Daily ingestion cap (e.g. 250 MB/day) still recommended as a guardrail against a runaway logging bug, independent of the credit — added in M7 |
| Key Vault | Live (M0) | Pay-per-10k-operations (~$0.03/10k) | ~$0 (pennies) | Never approaches a billable threshold at this scale |
| API Management (Consumption tier) | Live (M0), wired to the API (M2) | 1,000,000 calls/month free, then ~$3.50/million | $0 | No idle/base cost — serverless, scales to zero |
| Azure Container Apps | Live (M2) | 180,000 vCPU-s + 360,000 GiB-s + 2,000,000 requests/month free | Small, ongoing (see below) | `minReplicas` raised from 0 to 1 in M3 — Copilot Studio's tool-call timeout (30s, not configurable) is shorter than a cold start (image pull + Semantic Kernel init + first Azure OpenAI call), so scale-to-zero broke the Copilot Studio integration outright. Trades free-tier scale-to-zero for a always-on container at this size (~a few $/month) — accepted per ADR-0002, confirmed negligible against the credit at the time (€0.11 total spend before this change) |
| Azure Container Registry (Basic) | Live (M0) | None | ~$5/month flat | Preferred over GitHub Container Registry — genuinely Azure-native (managed identity pull auth into Container Apps, no PAT to manage), and ~$5/month is trivial against the $200 credit. See ADR-0002. |
| Azure Functions (Consumption) | Planned (M5) | 1,000,000 executions + 400,000 GB-s/month free | $0 | Comfortably covers ingestion pipeline / connector backends |
| Azure AI Search | Planned (M5) | Free (F0) tier: 50 MB storage, 3 indexes, no SLA | $0 | Sufficient for the RAG demo corpus; Basic tier (~$75/month) not needed |
| Azure OpenAI (bare resource, per ADR-0005) | Live (M2) | No free tier; pay-per-token. Deployed `gpt-5-mini` (`GlobalStandard` SKU — see below) | Usage-driven | Covered by the $200 credit at dev/demo volume; `gpt-5-mini` chosen specifically as the cost-efficient tier for iteration |
| Azure Service Bus (Basic tier) | Planned (M6) | No base cost, $0.05/million operations | $0 | Zero monthly floor |
| Azure Static Web Apps (Free plan) | Evaluate (M7) | 100 GB bandwidth/month, free custom domain + SSL | $0 | Only relevant if `/apps/web` ends up needed after the Power Apps evaluation |
| Azure Cost Management | Live (M0) | Budgets/alerts | $0 | Guardrail against the credit running out mid-build, not a one-time estimate |
| Power Platform environment + Dataverse | Live (M0) | Developer Plan: free, non-production | $0 | Sufficient for a portfolio demo; not licensed for production use — documented in `manual-setup.md` |
| Copilot Studio | Live (M3) | Free trial covers create + test-pane use fully; publishing needs paid capacity | $0 in practice | A pay-as-you-go billing plan (`copilotstudiopayg`, ~$0.01/Copilot Credit) was set up to unblock publishing, but per [ADR-0008](adr/0008-copilot-studio-licensing.md), the free trial alone was very likely sufficient for what this milestone actually needed — the Preview pane proves the same per-user RBAC chain a published channel would. The billing plan is left in place (not actively driving cost — nothing is published) rather than torn down mid-project; full teardown planned at project completion |
| Microsoft Graph API | Planned (M6) | Included with Entra ID / M365 | $0 | Standard throttling limits apply |
| GitHub Actions CI | Live (M0) | 2,000 free minutes/month (private) or unlimited (public) | $0 | Even a full milestone's CI stays inside the free allowance |
| Microsoft Fabric (evaluated per ADR-0001) | Planned (M8) | 60-day trial capacity, no permanent free tier | **Feasible now within the 30-day window** | With the credit-covered budget, a light Fabric implementation (not just a documented evaluation) is worth attempting for the reporting milestone (M8) — trial capacity comfortably outlasts the build window |
| Microsoft Purview (evaluated per ADR-0001) | Evaluate only (M8) | Consumption-based, no permanent free tier | Evaluate; implement only if trivial | Still likely evaluated-and-documented rather than deployed — Purview's consumption pricing is less predictable than Fabric's trial capacity, so it's the one place the $20 ceiling could get tight if implemented casually |

## Operating model under the revised policy

1. **Azure-native by default.** Where an earlier draft of this doc suggested a free-tier workaround (GitHub Container Registry instead of ACR), the Azure-native service is now preferred — it's simpler to operate and the cost difference is noise against the credit.
2. **The credit is the primary budget, not a stretch goal.** Azure Cost Management is configured to alert well before the $200 credit is exhausted, not just to report spend after the fact.
3. **The $20 figure is a ceiling on non-Azure-billed spend**, not a target — realistic exposure there is a handful of Copilot Studio pay-as-you-go message credits at $0.01 each if a live demo needs them.
4. **Nothing changes about *when* things run** — Container Apps still scale to zero, Functions/Service Bus/APIM still have no idle cost. The policy shift is about which service to pick when there's a trade-off, not about running things 24/7.

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
- If this project were ever taken toward real production use (out of scope for the portfolio), essentially every line above would need re-costing at production scale (Standard/Premium APIM, Standard AI Search, provisioned throughput for the LLM, Power Apps per-user licensing, etc.) — worth a one-line callout in the executive cost estimate deliverable when that's written.
