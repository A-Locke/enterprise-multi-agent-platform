# ADR-0004: Single tenant — new organizational user inside the existing Azure tenant

## Status

Accepted (supersedes [ADR-0003](0003-two-tenant-strategy.md))

## Context

ADR-0003 proposed resolving Power Platform's rejection of personal Microsoft accounts by getting a second tenant via the Microsoft 365 Developer Program. That signup returned:

> Thank you for joining. You don't currently qualify for a Microsoft 365 Developer Program sandbox subscription.

This is an automated eligibility check (account age/activity signals, prior program participation, etc.) that Microsoft Support cannot manually override — so that specific path is a dead end, not something worth retrying.

However, the actual root cause was never "no organizational tenant exists" — it was "the *signed-in account* is a personal Microsoft account." The Azure free account signup already created a real Entra ID tenant (`<tenant-id>`) behind the scenes, and the personal account is its Global Administrator. **A new user created inside that existing tenant is a genuine organizational account** (an `@<tenant>.onmicrosoft.com` identity backed by a real Entra ID directory) — it just needs to be created rather than obtained through a second signup flow.

The **Power Apps Developer Plan** signup (distinct from the M365 Developer Program) accepts any organizational account and provisions a free, indefinite, non-production Dataverse environment with no credit card and no eligibility gate — it's the standard "any Entra work account can self-serve a dev environment" flow.

## Decision

Stay on a **single Entra ID tenant** (the existing Azure tenant, `740c395a-...`):

1. In the Azure portal, while signed in as the personal-account Global Admin, create a new Entra ID user (e.g. `pp-admin@<tenant>.onmicrosoft.com`) and assign it Global Administrator (simplest for a portfolio sandbox; free — Entra ID Free tier covers built-in admin roles).
2. Sign in as that new user at the Power Apps Developer Plan signup — this provisions a free Dataverse-backed developer environment in the *same* tenant as all the Azure resources.
3. Use that same new user for `pac auth create`, Copilot Studio, and Power Platform admin center going forward.

This replaces ADR-0003's two-tenant plan. Consequences for ADR-0001's architecture:

- Entra ID App Roles (Admin / Agent User / Auditor) can now be **actual shared role definitions** used by both the Azure-side API and Dataverse security roles, rather than conceptually-mirrored-but-separate objects across tenants — simpler and more realistic for a single-org enterprise scenario, which is the more common case anyway.
- No cross-tenant B2B guest access or cross-tenant app permission grants needed anywhere in the design.
- Microsoft Graph calls (Teams/Outlook/SharePoint, Milestone 6) will need a Teams/Exchange/SharePoint license on this tenant, which the bare Azure default directory doesn't have — that's a separate, smaller gap to solve at Milestone 6 (likely a Microsoft 365 free/trial license assigned to the same tenant, evaluated then rather than now).

## Consequences

**Positive:**
- No second tenant, no cross-tenant identity complexity, no dependency on an eligibility-gated program that already rejected this account.
- $0 cost — Entra ID user creation and built-in role assignment are free; Power Apps Developer Plan is free and indefinite.
- Simpler RBAC story for Milestone 1: one real set of role definitions, not two mirrored ones.

**Negative / accepted trade-offs:**
- M365 workloads (Teams/SharePoint/Exchange) aren't available on this tenant yet — deferred to Milestone 6, to be solved with whatever free/trial licensing is available then rather than assumed now.
- `manual-setup.md` and `.env`/`.env.example` needed a second correction in one day — left as visible history in `PROJECT_JOURNAL.md` rather than cleaned up, since the iteration itself (try X, X gets rejected, find Y) is a realistic and worth-documenting part of the build.

## References

- [ADR-0003](0003-two-tenant-strategy.md) — superseded
- [`manual-setup.md`](../../manual-setup.md) #1–#3
- [`PROJECT_JOURNAL.md`](../../PROJECT_JOURNAL.md) — Milestone 0, blockers & resolutions
