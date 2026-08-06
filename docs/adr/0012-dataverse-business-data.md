# ADR-0012: Dataverse tables for agent configuration and audit logging

## Status

Accepted

## Context

Milestone 7 needs a primary business datastore for this platform (per ADR-0001's evaluation
principle, Dataverse first) and is where Milestone 1's deferred Dataverse security roles
finally land — deferred at the time specifically because creating them against zero real
tables would have meant empty, privilege-less role objects.

Two real, plausible pieces of business data this platform needs, not placeholder tables:

- **Agent Configuration** — which connectors/tools are wired to which agent, whether they're
  active, and a human-readable description. Something an Admin would actually manage as this
  platform grows past three hardcoded agents.
- **Conversation Audit Log** — who talked to which agent, when, and an outcome summary. The
  natural audit trail for a platform whose whole security model (Milestone 1) is per-user
  App Roles — a log of who actually exercised that access is the other half of that story.

"User-role mappings," the third item from the original plan, isn't a separate custom table —
it's redundant with Dataverse's own native user-to-security-role assignment, which the three
roles below already provide directly.

## How this gets built (and why not pure API scripting)

Table/column/role creation is technically scriptable via the Dataverse Web API
(`EntityMetadata`/`AttributeMetadata`/`role`/`roleprivileges` records), consistent with this
project's general preference for reproducible scripts over one-off manual steps. In practice,
hand-authoring that metadata blind — with no existing schema to start from — is meaningfully
more error-prone than building it once in the maker portal, where the schema/relationship/role
UI validates as you go.

Decision: build once via `make.powerapps.com` (Tables, Security roles, App designer), then
immediately capture the result as a Dataverse solution (`pac solution export` +
`pac solution unpack` into source-controlled files under `power-platform/solutions/`) —
the same template-then-generate discipline already established for the Power Platform
connector (Milestone 3). The manual step is genuinely one-time; re-deploying from the captured
solution via `pac solution import` is scripted and reproducible from then on.

## Decision

1. **`Agent Configuration`** table: name, description, connector reference (text — the
   connector's display name, not a hard foreign key, since connectors live outside Dataverse),
   active (boolean).
2. **`Conversation Audit Log`** table: agent name, user (lookup to the Dataverse user), timestamp
   (created-on, native), outcome summary (text).
3. **Three security roles**, scoped to these two tables, mirroring the Entra App Roles from
   Milestone 1:
   - **Admin**: full CRUD on both tables.
   - **Agent.User**: read on Agent Configuration, create + read-own on Conversation Audit Log
     (an agent user can see what happened in their own conversations, not everyone's).
   - **Auditor**: read-only on both tables, read-all (not read-own) on Conversation Audit Log —
     the whole point of an auditor role is seeing everyone's activity, not just their own.
4. **Power Apps model-driven admin app**: list/detail views over both tables, scoped by the
   security roles above (an Agent.User opening the app sees a different slice of data than an
   Admin, enforced by Dataverse's own row-level security, not application logic).
5. Captured as a solution (`power-platform/solutions/business-data/`) immediately after
   building, so the whole schema is reproducible via `pac solution import` from a clean
   environment.

## What actually happened building this

The plan held up; a few real quirks along the way:

- The Lookup column editor's "Related table" search didn't surface the built-in **User**
  (`systemuser`) table at all while a table was still being created inline, tried "User,"
  "Users," and "System User." Finishing the table first and adding the lookup as a separate
  step afterward also failed the same way at first — and the attempt left behind a **Lookup
  column self-referencing the table it was defined on**, which Dataverse won't let you delete
  once created (Data Type and Related Table are locked immutable after creation, by design,
  and this one has dependencies blocking removal entirely). Worked around it rather than
  fighting it: left the broken column in place, unused, and created a second lookup column
  (`UserLookup`) that correctly targets `systemuser` — the search worked normally on the
  second attempt, so this reads as a transient/one-off UI glitch rather than a real limitation.
- The table's auto-generated default form still referenced the broken column after
  `UserLookup` was added — new columns don't automatically get added to existing forms, so
  this needed a manual form edit (remove the stale field references, place the working one) as
  its own follow-up step, not something either the table or column creation handled for you.
- `pac solution export` needed a fresh interactive MFA re-authentication (`pac auth create`)
  even though the same profile had been working all session for `pac connector`/`pac env`
  operations — the same class of issue hit earlier with `pac admin list` (tenant-admin-scoped
  operations apparently require a stronger auth context than environment-scoped ones).
- The exported `Solution.xml` baked the live environment's org ID into the publisher's
  auto-generated `UniqueName`/`LocalizedName` fields — not something typed in deliberately,
  Dataverse derives it from the publisher's display name. Redacted to a plain alphanumeric
  placeholder (`PowerPlatformOrgId` — publisher unique names only allow `[A-Za-z0-9_]`, so the
  angle-bracket placeholder style used elsewhere in this repo isn't valid here). Confirmed via
  a full solution reimport that the placeholder doesn't break anything — Dataverse just
  recreates the publisher under that name on import, and the live environment's publisher
  record now matches it too, so later exports come out clean without needing to redact again.

## Consequences

**Positive:**
- Closes the loop on Milestone 1's deferred security roles with real, meaningful permission
  scopes rather than the empty stand-ins that would have existed if created back then.
- Dataverse's native row-level security (Agent.User seeing only their own audit entries)
  demonstrates a real Power Platform capability this project hadn't exercised yet.
- Reproducible from a clean environment via the exported solution, consistent with every other
  piece of this project.

**Negative / accepted trade-offs:**
- The one-time manual build step is real — no way around it for genuinely new schema
  authoring, same category of limitation as Copilot Studio's own agent authoring.
- The Conversation Audit Log isn't wired to actually *receive* real audit entries from the live
  agents yet (Copilot Studio doesn't write to Dataverse tables automatically just because they
  exist) — that wiring is deferred to Milestone 8 (Observability & Ops), where it belongs
  alongside the rest of this project's monitoring story rather than bolted on here.
- One orphaned, undeletable Lookup column (self-referencing, from the first failed attempt at
  the User relationship) sits unused on the Conversation Audit Log table — harmless, hidden
  from the form, but a permanent artifact of that troubleshooting rather than something worth
  further effort to remove.

## References

- [ADR-0001](0001-microsoft-platform-evaluation.md) — Microsoft Platform Evaluation principle
- Milestone 1 (`PROJECT_JOURNAL.md`) — the original deferral of Dataverse security roles
- `infra/entra/app-roles.json` — the Entra App Roles these Dataverse roles mirror
