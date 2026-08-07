# Future Roadmap

Ordered roughly by value-to-effort, not strictly by priority — each item traces to a real,
documented gap rather than a speculative feature.

## Near-term (extends what already exists)

- **Wire Application Insights into the API's application code.** The resource has existed
  since Milestone 0 but request/dependency tracing was never actually connected — a real,
  documented gap (`docs/observability.md`). Low effort (an SDK/middleware addition), real
  value (the alerting story goes from "we know something restarted" to "we know why").
- **Least-privilege Dataverse role for the Power Platform CI/CD service principal.** It
  currently holds System Administrator in both environments (risk register #8) — a custom
  security role scoped to solution import/export privileges only would close a real gap
  without changing pipeline behavior.
- **Extend the Power Platform Build Tools pipeline to a Prod-tier environment.** The current
  pipeline proves dev → test; a third environment and one more `pac admin assign-user` call
  (the same pattern established in [ADR-0013](../adr/0013-combined-release-process.md)) would
  complete the three-stage story.
- **Content Safety output moderation**, not just input. [ADR-0014](../adr/0014-content-safety.md)
  deliberately scoped to input-only for this pass; the model's own default filter covers
  output today, but a dedicated check would give consistent, project-controlled thresholds on
  both directions.

## Medium-term (new capability, same evaluation discipline)

- **Content Safety coverage for the Copilot Studio surface**, not just the pro-code API path
  — the platform's actual primary conversational surface currently relies entirely on
  Copilot Studio's own built-in moderation. Would need a custom action/plugin wiring, a
  materially bigger change than the current pass, evaluated per the same Microsoft Platform
  Evaluation principle as everything else in this project.
- **Resolve the Outlook connector's consent-persistence issue** — three separate investigation
  attempts this project ran (interactive, Maker mode, direct child-agent Preview) concluded
  it's a platform-side OAuth-grant-persistence issue, not something fixable from this side.
  Worth periodically re-testing as Copilot Studio's consent UI matures, since this class of
  preview-feature rough edge is exactly the kind of thing Microsoft iterates on.
- **Private Link for Key Vault/ACR/Azure OpenAI/AI Search/Content Safety.** Public network
  access is a deliberate, documented trade-off for this project's scale (risk register #4) —
  moving to Private Link is the concrete next step toward a production security posture.
- **Conditional Access / MFA policy**, requiring an Entra ID P1 upgrade — currently out of
  scope on cost grounds (Entra ID Free), a real recommendation for any production tenant.

## Longer-term (would change the shape of the platform)

- **Multi-region deployment.** Everything today runs in a single Azure region
  (`francecentral`) with no geo-redundancy — appropriate for a portfolio build, a genuine gap
  for production availability requirements.
- **A second, specialized Copilot Studio Connected Agent** beyond Knowledge and Enterprise
  Integration — the Connected Agents pattern ([ADR-0009](../adr/0009-copilot-studio-connected-agents.md))
  scales cleanly to additional domains; this project intentionally stopped at two to keep
  scope demonstrable rather than exhaustive.
- **Re-evaluate `DataZoneStandard` for Azure OpenAI** if a real compliance/data-residency
  requirement ever applies — the `GlobalStandard` choice was explicitly made because nothing
  forced otherwise ([ADR-0005](../adr/0005-azure-openai-over-ai-foundry.md)); revisiting it
  would also mean re-checking quota availability, since this wasn't just a preference.
- **Branch protection and required PR review on `main`**, once this moves beyond a
  single-contributor project — the CI jobs that would gate a required check already exist
  (`ci.yml`'s Bicep/API/Power Platform validation), just not enforced as a merge requirement.

## Deliberately not on this roadmap

Microsoft Fabric and Microsoft Purview were evaluated per [ADR-0001](../adr/0001-microsoft-platform-evaluation.md)
and found not to add value at this platform's actual scale — Azure Monitor workbooks and
Power Platform's native analytics already cover the reporting need; Dataverse security roles
and Azure RBAC already cover the governance need. Re-evaluating them isn't ruled out, but
neither is a default "do more Microsoft services" item on its own — consistent with this
project's whole evaluation discipline, adding either would need a real, new need to justify it.
