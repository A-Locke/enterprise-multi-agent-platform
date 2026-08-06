# Observability

This platform's observability story splits across two tracks, matching the project's two
deployment pipelines (ADR-0001) — Azure-side monitoring for the pro-code backend, and
Power Platform's own native analytics for the Copilot Studio/Dataverse side. Evaluated
together here rather than building a custom cross-cutting dashboard, since both sides already
have adequate native tooling on their own.

## Azure side: Azure Monitor

- **Log Analytics workspace** (`log-<token>`, Milestone 0) — receives Container App console
  logs (`ContainerAppConsoleLogs_CL`) and APIM diagnostic logs. Used throughout this project's
  own troubleshooting (e.g. diagnosing the Milestone 3/4 cold-start timeout via direct KQL
  queries) — this is the first place to look for anything unexpected.
- **Application Insights** (`appi-<token>`, Milestone 0) exists as a provisioned resource but
  is **not wired into the API's application code** — a real gap, not an oversight being hidden.
  Full APM/distributed tracing would need the OpenTelemetry/App Insights SDK added to
  `apps/api/app/`, a genuine code change out of scope for this milestone's alerting needs.
  Worth revisiting if this project ever needs request-level tracing rather than log-level
  visibility.
- **Alerts** (`infra/modules/monitoring.bicep`, Milestone 8): two metric alerts, one email
  action group.
  - `alert-containerapp-restart-spike`: fires once the current replica has accumulated 3+
    total restarts (`RestartCount`, `Maximum` aggregation — not any single restart, which
    Milestone 4 already documented as expected, self-healing platform behavior with
    `minReplicas: 1`). Originally used `Total` (Sum) aggregation, which false-fired within
    hours of deployment — `RestartCount` is a cumulative gauge, not a per-interval delta, so
    summing three consecutive readings of the same steady value inflated an artificial spike
    out of zero real restarts. Caught via the alert's own email notification, root-caused by
    querying the raw metric values directly, fixed by switching to `Maximum`. Full writeup in
    `PROJECT_JOURNAL.md`, Milestone 8.
  - `alert-apim-failed-requests`: fires on 5+ failed requests in 15 minutes — catches
    backend-down or auth-misconfiguration scenarios at the gateway.
- **Cost Management budget** (`budget-monthly-guardrail`, Milestone 0) — not traditionally
  "observability," but functionally the same category of guardrail; checked at the close of
  every milestone this session (see `PROJECT_JOURNAL.md`), consistently negligible spend.

## Power Platform side: native analytics

No custom tooling built here — the native surfaces already cover what this project needs:

- **Copilot Studio Analytics tab** (per-agent, in the maker portal) — session counts,
  resolution rates, topic/tool usage. The natural first stop for anything Copilot-Studio-side.
- **Dataverse auditing** — can be enabled per-table (Agent Configuration, Conversation Audit
  Log) for field-level change tracking, independent of the Conversation Audit Log table's own
  application-level logging (see below). Not enabled by default in this project — evaluate if
  compliance requirements ever call for it; the Auditor security role (ADR-0012) is already
  positioned to consume it if so.
- **Power Automate run history** — not currently relevant; this project has no Power Automate
  flows (ADR-0011 evaluated and deferred workflow automation, nothing async exists yet to have
  run history).

## The Conversation Audit Log

The Dataverse table built in Milestone 7 (ADR-0012) doesn't receive entries automatically just
because it exists — Copilot Studio doesn't write to arbitrary Dataverse tables on its own.
Wiring this up (a **Microsoft Dataverse** connector Tool on the parent agent, instructed to log
a summary after each conversation) is this milestone's attempt at closing that gap — see
`PROJECT_JOURNAL.md`, Milestone 8, for the outcome.

## References

- `docs/troubleshooting.md` — symptom-indexed reference for issues hit building all of the above
- [ADR-0012](adr/0012-dataverse-business-data.md) — Conversation Audit Log's design and the roles that consume it
- `docs/cost-analysis.md` — the budget guardrail as a cost-observability tool
