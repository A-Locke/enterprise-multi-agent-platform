# ADR-0005: Bare Azure OpenAI resource over a full Azure AI Foundry project

## Status

Accepted

## Context

ADR-0004's cost-policy revision explicitly framed the AI layer as an evaluation, not a
mandate: "evaluate Azure AI Foundry first; if a bare Azure OpenAI resource gives a simpler
implementation for this project's scope while preserving the architecture, document the
trade-off rather than defaulting to the newest service."

Two provisioning paths exist today, and they're closer together than they used to be:

- **Bare Azure OpenAI**: `Microsoft.CognitiveServices/accounts` with `kind: 'OpenAI'` — a
  single resource plus model deployments. Well-supported by Semantic Kernel's
  `AzureChatCompletion` connector directly.
- **Azure AI Foundry**: the same resource type with `kind: 'AIServices'` and
  `allowProjectManagement: true`, layering in a Foundry project, model catalog beyond
  OpenAI, the Agent Service, evaluation tooling, and unified observability. Microsoft's
  stated direction is that this becomes the default over time.

Critically, Microsoft has made this an **opt-in, reversible upgrade**: flipping
`kind: 'OpenAI'` to `kind: 'AIServices'` plus `allowProjectManagement: true` later preserves
the resource name, endpoint, and model deployments. Choosing the simpler path now doesn't
foreclose the richer one later.

For what Milestone 2 actually needs — one Semantic Kernel orchestrator calling one chat
model — none of AI Foundry's added surface (multi-project governance, model catalog breadth
beyond OpenAI, built-in Agent Service, evaluation pipelines) is used. Provisioning it now
would mean standing up a hub, a project, and Foundry-specific connections for zero
functional benefit at this milestone.

## Decision

Provision a **bare Azure OpenAI resource** (`kind: 'OpenAI'`) with one model deployment
(`gpt-5-mini`, version `2025-08-07`, `DataZoneStandard` SKU, EU data-residency-eligible,
`GenerallyAvailable` in `francecentral`) for Milestone 2. Authenticate via **Microsoft Entra
ID (RBAC)**, not API keys — `Cognitive Services OpenAI User` role assigned to the Container
App's managed identity (and, for local dev, the developer's own principal) — consistent
with the project's no-stored-secrets posture (ADR-0001, security model).

Note on model selection: the first attempt used `gpt-4.1-mini` (version `2025-04-14`), which
`az cognitiveservices model list` showed as present in the `francecentral` catalog — but
`azd provision` failed with `ServiceModelDeprecating: ... is in deprecating state and cannot
be used for new deployments`. The catalog listing itself doesn't surface deprecation status
by default; checking `lifecycleStatus` on each entry (not just presence in the list) is what
actually confirms a model/version is deployable. `gpt-5-mini` checked out clean
(`lifecycleStatus: GenerallyAvailable`).

Note on SKU: `gpt-5-mini` under `DataZoneStandard` (EU-only data residency) had 0 default
quota on this subscription; `GlobalStandard` (no processing-region guarantee) had 500 —
confirmed via `az cognitiveservices usage list`. Used `GlobalStandard` for Milestone 2,
since there's no real compliance requirement driving EU-only residency for a portfolio
project. Documented in `manual-setup.md` #6 as the concrete case of that manual gate; a
production engagement needing `DataZoneStandard` would request the quota increase instead.

Revisit the AI Foundry upgrade when a concrete need appears: the Agent Service (if it turns
out to cover ground the custom Semantic Kernel orchestrator would otherwise build by hand),
multi-model evaluation, or a second model provider beyond OpenAI. Until then, the extra
surface is unused complexity, not unused capability held in reserve for free.

## Consequences

**Positive:**
- Simpler Bicep, simpler mental model, faster to stand up and tear down while iterating.
- No cost or architectural difference in the token-billing model — `DataZoneStandard` is
  pay-per-token either way; choosing the simpler resource kind doesn't cost more or less.
- Managed-identity RBAC auth means zero secrets to manage for this resource, on either path.

**Negative / accepted trade-offs:**
- No Foundry-native Agent Service, evaluation harness, or multi-project structure — the
  Semantic Kernel orchestrator is fully custom-coded rather than partially declarative.
  Accepted: this milestone is explicitly meant to demonstrate the custom orchestration layer
  (ADR-0001's architecture), so building it by hand is the point, not a gap.
- If a future milestone needs AI Foundry's Agent Service specifically, upgrading involves a
  one-time resource property change plus adding a Foundry project — small, but not zero,
  work deferred rather than avoided.

## References

- [ADR-0001](0001-microsoft-platform-evaluation.md) — Microsoft Platform Evaluation principle
- [ADR-0004](0004-single-tenant-new-user.md) — established the "evaluate, don't mandate" framing for the AI layer
- `infra/modules/ai.bicep` — the resulting Bicep module
