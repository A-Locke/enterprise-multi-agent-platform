# ADR-0002: Cost policy — prefer Azure-native services within the free-credit window

## Status

Accepted (supersedes the $0-at-all-costs framing in the original `docs/cost-analysis.md`)

## Context

`docs/cost-analysis.md` (see [PROJECT_JOURNAL.md](../../PROJECT_JOURNAL.md), Milestone 0 addendum) originally targeted **$0/month sustained cost**, which pushed a couple of decisions toward free-alternative workarounds instead of the most natural Azure-native choice — most notably recommending GitHub Container Registry over Azure Container Registry solely to dodge ACR Basic's ~$5/month flat fee.

Two facts change the calculus:

1. The project will be substantially implemented within a **30-day window**, which is exactly the window the Azure free account's **$200 credit** covers in full.
2. The user is explicitly willing to accept **up to $20 out-of-pocket** beyond whatever the credit doesn't reach.

Optimizing for literal $0 under those conditions trades real engineering simplicity (e.g., ACR's native managed-identity pull auth into Container Apps, vs. managing a PAT for `ghcr.io`) for a saving that's already covered by unused credit. That's a worse trade for a project meant to demonstrate solid Azure engineering judgment, not cost-minimization at the expense of using the platform as intended.

## Decision

Within the 30-day build window:

- **Prefer the Azure-native service** for any capability where an earlier evaluation chose a free alternative specifically to avoid a small flat fee (ACR over GHCR being the concrete case today).
- **Treat the $200 Azure credit as the primary budget**, tracked via an Azure Cost Management budget with alert thresholds set well below the credit ceiling (see `docs/cost-analysis.md`), not as a hard limit to avoid touching.
- **Accept up to $20 of spend that Azure billing doesn't cover** — realistically only Copilot Studio pay-as-you-go message credits if a live demo needs more than the free build/test mode provides.
- This does **not** change the *Microsoft Platform Evaluation* principle (ADR-0001) — Power Platform vs. Azure pro-code decisions are still made on architectural fit, not cost. This ADR only changes the tie-breaker when a decision was being made on cost grounds alone.
- Usage-driven costs (LLM tokens, API calls beyond free grants) still default to the cheapest reasonable option (e.g., GPT-4o-mini for iteration) — the policy relaxes *fixed-fee* avoidance, not usage discipline.

## Consequences

**Positive:**
- Simpler operational story: Container Apps pulls images from ACR via managed identity, no PAT/token to rotate for a registry.
- Removes a documented workaround (`docs/cost-analysis.md` previously flagged GHCR-over-ACR as an ADR-worthy trade-off) that existed only to satisfy a budget constraint that no longer applies.

**Negative / accepted trade-offs:**
- If the project extends past the 30-day window or the $200 credit is otherwise consumed faster than expected (e.g., heavier-than-planned LLM usage), ACR's flat fee becomes real out-of-pocket spend rather than credit-covered spend. Accepted given the explicit $20 tolerance.
- Microsoft Fabric's 60-day trial capacity is now worth attempting as a light implementation (per `docs/cost-analysis.md`) rather than evaluation-only — slightly more scope in Milestone 8, accepted because the trial capacity is free regardless of this policy change.

## References

- [`docs/cost-analysis.md`](../cost-analysis.md) — full per-resource cost breakdown under this policy
- [ADR-0001](0001-microsoft-platform-evaluation.md) — Microsoft Platform Evaluation principle (unaffected by this ADR)
