# Risk Register

Risks are rated Likelihood × Impact (Low/Medium/High) against this platform as it stands
today, with the actual mitigation in place (or the honest gap, if none exists).

| # | Risk | Likelihood | Impact | Mitigation in place | Residual gap |
|---|---|---|---|---|---|
| 1 | Standing CI/CD credentials (Azure MSI, Power Platform service principal) compromised | Low | High | Scoped as narrowly as practical — Azure MSI limited to `rg-dev` (Contributor + RBAC Administrator, not subscription-wide); Power Platform SP is a Dataverse Application User, not a tenant-wide admin | Both hold genuine write access; neither has an expiry/rotation policy configured. In scope for the [project teardown plan](../../PROJECT_JOURNAL.md) at project end |
| 2 | Copilot Studio conversations bypass the platform's Content Safety layer | High (by design) | Medium | Copilot Studio has its own Microsoft-managed moderation, independent of this project's code | The dedicated Content Safety check ([ADR-0014](../adr/0014-content-safety.md)) only covers the pro-code `/agent/chat` path, not the primary conversational surface |
| 3 | No Conditional Access / MFA policy on the Entra tenant | Medium | Medium | Entra ID Free tier is a deliberate cost/scope trade-off for this project | A production tenant would need Conditional Access (P1) as a baseline, not optional |
| 4 | Public network access enabled on Key Vault/ACR/Azure OpenAI/AI Search/Content Safety | Medium | Medium | All traffic is HTTPS-only; access is Entra ID RBAC-gated (no API keys anywhere to leak) | Network-layer restriction (Private Link) is the real production recommendation — not configured here, documented as a known trade-off in `docs/security-model.md` |
| 5 | Application Insights provisioned but not wired into application code | High (already true) | Low | Azure Monitor alerting (restart spikes, APIM failures) is live and independent of App Insights | No request/dependency-level tracing exists yet — an incident would have alert signal but not detailed trace data. Documented in `docs/observability.md`, not hidden |
| 6 | Single points of authoring for genuinely manual steps (Copilot Studio agent config, Dataverse schema) | High | Medium | Fully captured as source-controlled solutions immediately after each manual build (`pac solution export`/`unpack`), reproducible from a clean environment | The *original* authoring step itself has no redundancy — if the one person who built it is unavailable, the maker-portal knowledge to modify it (not just redeploy it) doesn't transfer via the repo alone |
| 7 | Azure OpenAI model deployment uses `GlobalStandard` (no data-residency guarantee) | Low (no real compliance need today) | High (if requirements change) | Documented trade-off, not an oversight — [ADR-0005](../adr/0005-azure-openai-over-ai-foundry.md), `manual-setup.md` #6 | A compliance-driven engagement would need to request `DataZoneStandard` quota and re-evaluate every downstream assumption that follows from processing region |
| 8 | Dataverse security roles hold "System Administrator" for both CI/CD Application Users | Low | Medium | Necessary for `pac solution import` to succeed reliably against arbitrary schema changes; narrower custom roles were not attempted | A least-privilege custom Dataverse role (import-only, not full admin) is a real, unimplemented improvement — noted in [`roadmap.md`](roadmap.md) |
| 9 | No branch protection / required PR review on `main` | High (single-contributor project) | Low today, Medium at team scale | N/A — appropriate for a single-person build | Before any real team adoption, branch protection + required status checks (the CI jobs already exist to gate on) would need enabling |
| 10 | Azure Cost Management budget scoped to `rg-dev` only, not subscription-wide | Low | Medium | Everything in this project lives in that one resource group today | A resource accidentally created outside `rg-dev` wouldn't trigger the budget guardrail — worth widening if that assumption ever changes |

## How this register was built

Every row above traces to something real: an ADR, a documented known limitation in
`docs/security-model.md`, or a gap explicitly called out in `PROJECT_JOURNAL.md` — not a
generic checklist. Risks that don't apply to this platform's actual architecture (e.g.,
"third-party dependency vulnerabilities" for a platform with almost no third-party runtime
dependencies) were deliberately left off rather than padding the table.
