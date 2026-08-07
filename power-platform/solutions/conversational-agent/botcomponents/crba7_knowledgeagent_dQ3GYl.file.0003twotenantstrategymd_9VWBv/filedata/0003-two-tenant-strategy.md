# ADR-0003: Separate Entra ID tenants for Azure and Power Platform/M365

## Status

**Superseded by [ADR-0004](0004-single-tenant-new-user.md).** The Microsoft 365 Developer Program's instant sandbox — the mechanism this ADR relied on for the second tenant — returned an automated, unappealable "you don't currently qualify" rejection. ADR-0004 documents a better resolution that avoids a second tenant entirely. Left here for the historical record of the decision process.

## Context

While bootstrapping local tooling auth (`manual-setup.md` #2), `pac auth create` failed:

```
AADSTS500200: User account '<personal-account-email>' is a personal Microsoft account.
Personal Microsoft accounts are not supported for this application unless
explicitly invited to an organization.
```

The Azure free account was created with a personal Microsoft account. Azure accepts this and auto-provisions a bare "default directory" (Entra ID tenant) behind the scenes — `az login`/`azd auth login` succeeded fine against it, and the $200 free credit is attached to that subscription. Power Platform (Dataverse, Power Apps, Power Automate, Copilot Studio), however, explicitly rejects personal Microsoft accounts at sign-in: it requires a genuine "work or school" organizational account, which a bare default directory doesn't provide (no licensing, no real org structure).

Two ways to resolve this were considered:

1. **Consolidate into one tenant** — either re-associate the existing Azure subscription's directory to a new organizational tenant, or provision a second Azure subscription inside a new organizational tenant.
2. **Accept two tenants** — keep Azure resources in the personal-account-derived tenant (preserving the $200 credit with zero risk), and get a second, proper organizational tenant via the free Microsoft 365 Developer Program specifically for Power Platform/Copilot Studio/M365.

Option 1 carries real, hard-to-reverse risk: Azure free-trial subscriptions don't reliably support directory re-association, and it's unconfirmed whether a second Azure subscription under a new tenant would receive a fresh $200 credit or just standard pay-as-you-go billing. Given the project's cost policy (ADR-0002: $200 credit as primary budget, $20 out-of-pocket ceiling), risking the credit to achieve a marginally cleaner tenant topology isn't worth it.

## Decision

**Accept two separate Entra ID tenants:**

- **Azure tenant** (personal-account-derived default directory): hosts all Azure resources (Container Apps, APIM, AI Foundry/OpenAI, AI Search, Key Vault, etc.) and the Entra ID app registrations that protect them (Milestone 1).
- **Power Platform / M365 tenant** (Microsoft 365 Developer Program sandbox, free, 90-day renewable, no credit card): hosts Power Apps, Power Automate, Dataverse, Copilot Studio, and Teams/SharePoint/Exchange for the Microsoft Graph integration milestone (M6).

Consequences for the architecture already committed in ADR-0001:

- Entra ID App Roles (Admin / Agent User / Auditor) are defined **per tenant** where they're consumed — the Azure-side API's roles live in the Azure tenant; Dataverse security roles live in the Power Platform tenant. They are conceptually mirrored (same role names, same intent) but are not the same Entra objects.
- Any component that needs to call across the boundary (e.g., a Semantic Kernel agent in the Azure tenant calling a Dataverse-backed Power Automate flow, or Copilot Studio's custom action calling the APIM-fronted backend) authenticates cross-tenant via a dedicated app registration with explicit permissions granted in the *target* tenant, rather than assuming a shared identity.
- This is presented as a deliberate, documented trade-off rather than a workaround: multi-tenant boundaries are common in real Microsoft consulting engagements (e.g., a client's Azure landing zone tenant vs. a separate M365 tenant, or ISV scenarios), so designing the cross-tenant call path explicitly is itself a relevant architectural demonstration, not just a portfolio-project compromise.

## Consequences

**Positive:**
- Zero risk to the $200 Azure credit already in hand.
- The Microsoft 365 Developer Program tenant is free, well-supported, and provides M365 workloads (Teams/SharePoint/Exchange) needed for M6 regardless — it would likely have been added anyway.
- Forces an explicit, documented cross-tenant auth design rather than an implicit same-tenant assumption — arguably a more realistic consulting scenario.

**Negative / accepted trade-offs:**
- Slightly more setup: two sign-ins, two sets of app registrations, explicit cross-tenant permission grants instead of one shared identity.
- `.env` needs to track two tenant IDs (`AZURE_TENANT_ID`, `POWER_PLATFORM_TENANT_ID`) instead of one.
- Milestone 1's RBAC demo will show "mirrored" roles across tenants rather than a single shared role definition — worth calling out explicitly in that milestone's documentation so it doesn't read as an oversight.

## References

- [`manual-setup.md`](../../manual-setup.md) #1–#3
- [ADR-0002](0002-cost-policy.md) — cost policy that ruled out the directory-consolidation option
- [`PROJECT_JOURNAL.md`](../../PROJECT_JOURNAL.md) — Milestone 0, blockers & resolutions
