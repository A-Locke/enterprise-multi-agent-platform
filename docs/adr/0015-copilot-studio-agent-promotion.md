# ADR-0015: Promoting the Copilot Studio agent through the Power Platform pipeline

## Status

Accepted

## Context

ADR-0013 closed Milestone 9 with the Power Platform Build Tools pipeline promoting only the
Dataverse business-data solution (tables, roles, admin app) from dev to test — the Copilot
Studio agent itself was explicitly out of scope, and wasn't even captured as a
source-controlled solution at all (`manual-setup.md` #5 had originally called for this, but
it never happened). During a post-Milestone-10 verification pass, this gap became concrete:
opening the test environment's Copilot Studio dashboard showed zero agents, and there was no
reproducible way to get them there other than re-authoring by hand.

## Decision

Capture the agent as its own source-controlled Dataverse solution and extend
`power-platform-deploy.yml` to promote it alongside business-data:

1. **`power-platform/solutions/conversational-agent`**: the parent agent ("Multi-Agent
   Platform") and both Connected Agents (Knowledge, Enterprise Integration) — topics,
   generative orchestration config, Connected Agent routing, and (for the Knowledge agent)
   its indexed file corpus — captured via the maker portal's Solutions UI ("Add existing" →
   Copilot; Dataverse's generic `AddSolutionComponent` API has no registered component type
   for bots at all, confirmed against Microsoft's own full `componenttype` reference, so this
   step is portal-only, the same category of manual step as the agent's original authoring).
2. **`power-platform/solutions/platform-api-connector`**: the custom connector the parent
   agent's API action depends on, captured as its **own**, separate solution — required by a
   documented Microsoft "Known issue": custom connectors must be exported/imported in a
   solution separate from anything referencing them, before that referencing solution.
3. The pipeline imports `platform-api-connector` before `conversational-agent`, then
   pre-creates a placeholder `connectionreference` record (matching the exact logical name
   the agent's action expects) pointing at test's freshly-imported connector, before
   attempting the agent import.

## What actually happened capturing this

The path here was long enough to be worth recording in full — six distinct real findings,
each verified against actual Dataverse responses:

1. **Test environment access is gated separately per surface.** `admintest` (the account that
   created the test Dataverse environment) couldn't see anything in Copilot Studio at all —
   not a Dataverse permissions problem, but because the **Copilot Studio Authors** Entra
   security group (a tenant-wide setting, ADR-0008) only ever had the original authoring
   account as a member. Copilot Studio licensing and Dataverse environment access are two
   independent gates.
2. **Bots have no registered `componenttype`.** Confirmed by pulling all 90 entries directly
   from the org's own `componenttype` global option set metadata (matches Microsoft's public
   reference exactly) — nothing for "Bot." The only supported way to add one to a solution is
   the maker portal's own Solutions UI.
3. **Custom connector export fails inside a bot's solution.** Exporting `ConversationalAgent`
   failed with `Exporting connection reference ... for a custom connector requires the custom
   connector to be added to a dataverse solution`, regardless of the connector's actual
   solution membership — tried it present, tried it absent, tried the maker portal's own
   native export (not just `pac`) to rule out a CLI-specific bug. All three failed identically.
   The actual fix, found in Microsoft's documented "Known issues" for connection references:
   the connector needs its **own dedicated solution**, exported and imported **before** the
   solution containing the reference to it — not merely present in the same one.
4. **Even correctly separated, the connection reference itself can't be exported.** Once the
   connector had its own solution, the export succeeded only after removing the connection
   reference component from `ConversationalAgent` entirely (`RemoveSolutionComponent` — note
   the actual parameter is `SolutionComponent` bound to the component's own ID, not a
   `solutioncomponent` junction-record ID; the Web API's error messages for this action are
   confusing enough that this took two failed attempts to get the payload shape right).
5. **Custom connectors get a new environment-specific internal ID on every import.** Verified
   directly: dev's connector had `connectorinternalid` ending `...44e6bfd929e5f407`; the same
   connector re-imported into test came back ending `...d8ba501759f95b99`. This is also a
   documented Microsoft "Known issue" and is the root cause of finding 4 — a connection
   reference's logical name bakes in this hash, so it can never validly reference the same
   connector across two environments, regardless of solution structure. There's no clean fix
   for this today; the connection genuinely needs manual recreation per environment.
6. **A placeholder connection reference is enough to satisfy import, not to make it work.**
   Pre-creating a `connectionreference` record in test with dev's exact (stale) logical name,
   pointed at test's own connector, was enough for `ConversationalAgent` to import
   successfully end-to-end. The actual OAuth connection still needs a one-time manual
   reconnect in test's maker portal afterward — the same category of manual step this project
   already accepted for the Teams/Outlook connections (ADR-0011, `docs/troubleshooting.md`).

Along the way, redacted several real values found embedded in the exported files that hadn't
been caught by earlier sweeps — a real tenant ID, the API app's client ID, the APIM hostname,
and the connector's own redirect URI, all inside the connector's `connectionparameters.json`
and `openapidefinition.json`, plus the parent agent's Dataverse action storing a real
environment URL as a default value. All now placeholder-committed and hydrated from GitHub
secrets at pack time, matching the pattern already established for `business-data`.

## Consequences

**Positive:**
- The Copilot Studio agent — this platform's actual primary conversational surface — now has
  a genuine, reproducible, verified-live promotion path, not just the Dataverse business layer
  around it. Confirmed via direct API query: all three bots present in test, both new
  solutions correctly `ismanaged: true`.
- Closes the gap `manual-setup.md` #5 originally flagged and never followed through on.
- Every root cause here is backed by either a direct Dataverse API verification or an
  authoritative Microsoft documentation citation — none of the six findings above are
  speculative.

**Negative / accepted trade-offs:**
- The custom-API action's connection needs a manual one-time reconnect in every new
  environment — a real, structural platform limitation (finding 5), not a gap in this
  project's automation. No amount of pipeline engineering resolves it today.
- The placeholder connection reference is a deliberate workaround, not a clean solution — it
  satisfies Dataverse's import-time dependency check without providing a working connection.
  Anyone extending this pipeline to a third environment needs to repeat the same placeholder
  step, not just re-run the existing one (the logical name is hardcoded to dev's original
  hash and would need updating if the connector in dev is ever recreated from scratch).
- `power-platform-deploy.yml` now has real import-order coupling (connector before agent, both
  before the placeholder-reference step) that didn't exist when it only handled business-data
  — a genuine increase in pipeline complexity, traded for genuine new capability.

## References

- [ADR-0013](0013-combined-release-process.md) — the pipeline this extends
- [ADR-0009](0009-copilot-studio-connected-agents.md) — the Connected Agents pattern being
  promoted
- [ADR-0008](0008-copilot-studio-licensing.md) — the Copilot Studio Authors group finding 1
  traces back to
- `manual-setup.md` #5 — the original, unfulfilled intent this ADR closes
- `.github/workflows/power-platform-deploy.yml`, `power-platform/solutions/conversational-agent`,
  `power-platform/solutions/platform-api-connector`
