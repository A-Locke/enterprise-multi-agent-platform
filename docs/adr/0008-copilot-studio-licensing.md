# ADR-0008: Copilot Studio licensing — pay-as-you-go billing, kept but not strictly required for this milestone

## Status

Accepted

## Context

Authoring the Copilot Studio agent (Milestone 3) hit a licensing wall: saving any change to the agent failed with `You don't have permission to create agents / User license not found`, even though the connector, redirect URIs, and Entra permissions were all correctly configured by that point.

Investigation (Microsoft's own troubleshooting docs) surfaced that Copilot Studio access is gated by several independent, unrelated permission systems, not one:

1. A **Copilot Studio authors** Microsoft Entra security group, assigned under the tenant setting of the same name (Power Platform admin center).
2. A **Copilot Studio user license** or trial, assigned per-user (Microsoft 365 admin center).
3. **Publishing** specifically (not creating/testing) additionally requires either a paid tenant-level Copilot Credit subscription or pay-as-you-go billing linked to an Azure subscription.
4. Separately, actually *purchasing or activating* anything in the Microsoft 365 admin center required a **Microsoft 365 billing account role** — a fourth, distinct permission system from the three above, uncovered only because a trial checkout button stayed permanently disabled until a missing billing-account address field was fixed.

None of these are documented as a single checklist anywhere; each was found by hitting its specific failure and researching that failure in isolation.

## Decision

Set up, in this order, as each blocker was found:

1. **Copilot Studio Authors security group** (`az ad group create` + membership) — assigned under Power Platform admin center → Tenant settings.
2. **Pay-as-you-go billing plan** (`copilotstudiopayg`) linking the `dev-eu-a7389295` environment to the Azure subscription, scoped to the Copilot Studio meter specifically (not Dataverse/Power Apps/Power Automate, which would have billed a wider surface than intended). Creating this required granting the Power Platform admin account **Contributor** on the Azure subscription (it had zero prior RBAC there — a separate organizational user from the one that owns the subscription, per ADR-0004) — a broad grant, confirmed explicitly with the user before applying, left in place per their direction.
3. **Microsoft Copilot Studio Trial** license, activated after 1 and 2 alone still didn't resolve the "create agents" error — required fixing a missing address field on the Microsoft 365 billing account first, which was blocking all purchases/trial activations silently (manifesting as a permanently-disabled "Try now" button, not an explicit error).

After all three were in place, saving/creating agents started working.

### Finding: the trial alone was probably sufficient for what this milestone actually needed

Microsoft's own docs state plainly: *"The trial license gives you access to Copilot Studio to create agents. You can test your agents using the test chat panel. However, you can't publish the agent."* That's exactly the capability this milestone ended up needing — the **Demo Website** channel turned out to require disabling the agent's own authentication entirely (a hard platform requirement, not a bug), which defeats the purpose of demonstrating per-user delegated auth; and the **Teams** channel's sign-in is currently broken for this tenant (a `We couldn't find a Microsoft account` error, almost certainly another manifestation of this tenant's personal-account origin — see ADR-0004 — rather than anything specific to this project's configuration).

Given that, **publishing isn't something this milestone actually needed**: the Preview/test chat pane already demonstrates the full, real chain — Copilot Studio's per-user identity flowing through the connector's delegated OAuth, into the platform API's Entra App Role check (Milestone 1's RBAC), through Semantic Kernel, to a real Azure OpenAI response. That's the architectural claim this project is making, proven without needing a published, externally-reachable channel at all.

Which means: **the pay-as-you-go billing plan and the Contributor RBAC grant it required were very likely unnecessary** — the trial alone, once the billing-account address issue was fixed, would probably have been sufficient for create-and-test. The two efforts happened close together, so this can't be proven with certainty in hindsight, but the balance of evidence (Microsoft's docs, and that only *publishing* is trial-gated) points that way.

### Decision: leave it as-is for now, document the finding

The user's explicit direction: keep the billing plan, the Contributor grant, and everything else exactly as configured for the remainder of the project — reverting things that "worked well enough" adds risk (a repeat of the whole licensing maze) for a benefit (a few euros of avoided pay-as-you-go exposure) that's negligible against the already-established budget. Publishing may become relevant again later (e.g. a Milestone 10 demo recording, or if Teams' sign-in issue resolves itself), at which point the pay-as-you-go plan would already be in place rather than needing to be rebuilt.

Instead: this ADR records the finding honestly, and a full teardown (delete all project accounts, unlink billing, destroy the temporary payment card) is planned for when the project concludes — see the project's teardown plan (tracked outside the repo, not itself something to script prematurely).

## Consequences

**Positive:**
- Unblocked agent authoring without further delay once the actual root causes were found.
- Real, working end-to-end proof of the per-user RBAC chain via Preview, achieved without needing to resolve either the Demo Website auth conflict or the Teams sign-in bug.
- The permission-system landscape (four independent gates) is now documented for anyone else standing up Copilot Studio on a similarly unusual (personal-account-derived) tenant.

**Negative / accepted trade-offs:**
- A broad Azure subscription Contributor grant and a live pay-as-you-go billing link remain in place for a capability (publishing) not currently exercised — an intentional, confirmed decision to avoid rework risk, not an oversight, with teardown deferred to project completion rather than done now.
- Teams publishing remains unverified; if it's needed later (demo recording), the sign-in issue will need revisiting at that point.
- Demo Website is confirmed structurally incompatible with this project's per-user-auth design (requires disabling authentication entirely) — not pursued further as a channel.

## References

- [ADR-0004](0004-single-tenant-new-user.md) — the personal-account-derived tenant and organizational user, root cause of both the Contributor RBAC gap and (likely) the Teams sign-in issue
- [ADR-0002](0002-cost-policy.md) — cost policy this decision was weighed against
- `docs/cost-analysis.md` — updated with the Copilot Studio pay-as-you-go and Container App `minReplicas: 1` cost lines
- `manual-setup.md` #10 — reproducing this licensing setup from scratch
