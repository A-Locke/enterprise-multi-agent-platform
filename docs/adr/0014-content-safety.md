# ADR-0014: Azure AI Content Safety as a dedicated moderation layer

## Status

Accepted

## Context

ADR-0001's Microsoft Platform Evaluation principle calls out Azure AI Content Safety
specifically as a capability to evaluate for the pro-code side of this platform, and
`docs/security-model.md` has carried it as a "known limitation, not implemented" since
Milestone 2. Two things were already true before this ADR: Azure OpenAI's own default
content filter (`raiPolicyName: Microsoft.Default` in `infra/modules/ai.bicep`) has been
active on every model call since the resource was created, and Copilot Studio — this
platform's primary conversational surface — carries its own Microsoft-managed moderation as
a platform feature, entirely outside this project's code. Neither of those is something this
project built or can meaningfully take credit for; they're defaults.

The evaluation question for Milestone 10 (Hardening) is narrower: is a *dedicated*,
separately-configurable Content Safety layer worth adding on top of those defaults for the
one pro-code endpoint this platform does own (`/agent/chat`, Milestone 2's Semantic Kernel
agent)? For a Microsoft AI Consultant portfolio piece specifically, responsible-AI tooling is
a real, frequently-asked-about capability — worth implementing for real rather than leaving as
a documented gap, given the actual cost and integration effort turned out to be small.

## Decision

Add **Azure AI Content Safety** (`infra/modules/content-safety.bicep`, F0/free tier,
`disableLocalAuth: true` — Entra ID RBAC only, matching every other Cognitive Services
resource in this project) as a text-moderation check on user input, called from
`apps/api/app/content_safety.py` before the message reaches Semantic Kernel/Azure OpenAI.

- **Authentication**: managed identity (`Cognitive Services User` role, granted via the
  existing `ai-rbac.bicep` module — reused as-is; its `existing` resource lookup is generic
  across Cognitive Services kinds despite the `openAiName` parameter name), same pattern as
  every other Azure dependency in this project. No API keys.
- **Threshold**: severity ≥ 2 (of 0–6) in any of the four harm categories (Hate, SelfHarm,
  Sexual, Violence) blocks the request with a `400`. This is Microsoft's own documented
  "medium" baseline severity for blocking user-generated content, not an arbitrary number
  picked for this project.
- **Fail-open, not fail-closed**: if the Content Safety service itself is unreachable or
  errors, the request proceeds rather than being blocked. An optional defense-in-depth layer
  becoming a denial-of-service vector for the whole chat endpoint on its own outage would be
  a worse outcome than occasionally missing a moderation check — the underlying model's own
  default content filter still applies regardless, so this isn't the only safety net.
- **Scope**: input moderation only (the user's message before it reaches the model), not
  output moderation of the model's response. Azure OpenAI's own content filter already
  screens both directions at the model layer; this addition specifically demonstrates the
  dedicated-service pattern rather than duplicating filtering the platform already does.

## Consequences

**Positive:**
- Closes a gap that had been an explicitly documented "not implemented" item since Milestone
  2 — with real code, real infrastructure, and a real test (`tests/test_content_safety.py`:
  allows low severity, blocks high severity, fails open on a service error), not just an ADR
  saying it was considered.
- F0 tier is free (same cost posture as every other resource in this project) — no budget
  impact, confirmed via `az consumption budget list` after deployment.
- Demonstrates the Cognitive Services managed-identity RBAC pattern extends cleanly to a
  second resource kind without new plumbing — `ai-rbac.bicep` needed zero changes to work
  against a `ContentSafety` account instead of an `OpenAI` one.

**Negative / accepted trade-offs:**
- Copilot Studio's own conversations (the platform's actual primary surface) don't route
  through this check — it only covers the pro-code `/agent/chat` endpoint. Extending
  moderation to the Copilot Studio path would mean wiring it as a custom action/plugin call,
  which is a materially bigger change than this ADR's scope; documented here as a real gap,
  not silently out of scope.
- Fail-open is a deliberate availability-over-strictness trade-off — a determined actor could
  in principle time requests around a Content Safety outage. Acceptable for this project's
  threat model (portfolio/demo traffic, not a production moderation SLA); would be worth
  revisiting for a real production engagement.
- Output moderation (the model's response, not just the user's input) is out of scope for
  this pass — Azure OpenAI's own filter covers that layer already, so the marginal value of
  duplicating it here is lower than covering user input was.

## References

- [ADR-0001](0001-microsoft-platform-evaluation.md) — Microsoft Platform Evaluation principle,
  which named Content Safety as an evaluation target
- [ADR-0005](0005-azure-openai-over-ai-foundry.md) — the Azure OpenAI resource this sits
  alongside
- `docs/security-model.md` — updated to reflect this as implemented, not planned
- `apps/api/app/content_safety.py`, `infra/modules/content-safety.bicep`
