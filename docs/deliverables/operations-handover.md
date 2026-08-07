# Operations Handover Guide

For whoever is on the hook when something breaks in production. What to watch, what a real
alert means, and where to look first.

## What's actually monitored today

- **Azure Monitor metric alerts** (`infra/modules/monitoring.bicep`): a Container App
  restart-spike alert (threshold 3 restarts, `Maximum` aggregation — deliberately not `Total`,
  see the note below) and an APIM failed-requests alert (threshold 5, `Total` aggregation).
  Both notify a single email action group.
- **Power Platform native analytics**: Copilot Studio's own Analytics tab (conversation
  volume, topic resolution rates) and Dataverse's built-in auditing — no custom tooling
  needed here, the native surfaces already cover it (`docs/observability.md`).
- **Azure Cost Management budget** (`infra/modules/budget.bicep`): alert thresholds at
  50/75/90/100% of $180/month, scoped to `rg-dev`. Check `az consumption budget list`
  periodically even without a triggered alert — this project's own practice is a check at the
  close of every milestone, not just when notified.

## What's *not* monitored (known gaps, not oversights)

- **No request/dependency tracing.** Application Insights has been provisioned since
  Milestone 0 but was never wired into the API's application code — an incident today would
  have alert signal (something restarted, something failed) but no trace-level detail on why.
  See [`roadmap.md`](roadmap.md) — this is the top near-term item for a reason.
- **No alerting on the Content Safety or AI Search resources specifically** — both are behind
  the same Container App/APIM alerts, but neither has a dedicated health signal of its own.
- **The CI/CD pipelines have no automated failure notification** beyond GitHub's own
  run-status UI — a failed deploy doesn't page anyone.

## A restart-spike alert just fired — what do I do?

1. Check `ContainerAppConsoleLogs_CL` in Log Analytics for the actual crash reason first —
   don't assume it's the same issue as last time.
2. **Known false-positive history**: this alert originally used `Total` (Sum) aggregation and
   fired on a container that hadn't actually restarted — `RestartCount` is a cumulative gauge,
   not a per-interval delta, so summing it inflated a fake spike. Fixed by switching to
   `Maximum` (see `PROJECT_JOURNAL.md`, Milestone 8). If this alert is firing again, verify
   the aggregation setting hasn't regressed before assuming a real restart loop.
3. Check `docs/troubleshooting.md` for the symptom before deep-diagnosing from scratch.

## An APIM failed-requests alert just fired — what do I do?

1. Check the backend (Container App) health first — APIM here is a passthrough
   (`set-backend-service` policy), so a failure is very likely upstream, not in APIM itself.
2. Confirm the Container App's managed identity RBAC is still intact (`AcrPull`, `Cognitive
   Services OpenAI User`, `Cognitive Services User`) — a role assignment removed by an
   unrelated cleanup would surface here as auth failures against Azure OpenAI/Content Safety.

## Deploying a change

Both pipelines are `workflow_dispatch`-only — deliberate, reviewed deployments, not
auto-deploy-on-push. See [`technical-handover.md`](technical-handover.md) for the mechanics;
operationally, the thing to know is: **nothing deploys without someone explicitly triggering
it**, so a "why hasn't my merged PR shown up in prod" question almost always means the
workflow just hasn't been run yet, not that something's broken.

## Rotating the standing secrets

Two credentials exist that aren't managed-identity-based and do need periodic attention:

- **Copilot Studio connector client secret** (Key Vault) — expires after 1 year. Check
  `az ad app credential list --id <api-app-id>` for the expiry date; rotation steps are in
  `manual-setup.md` #9.
- **Power Platform pipeline service principal secret** (Key Vault + GitHub secret) — no
  expiry was set explicitly at creation; check `az ad app credential list --id
  <pp-pipeline-app-id>` and rotate proactively rather than waiting for a CI failure to
  discover it lapsed.

## Cost checks

Run `az consumption budget list` and, separately, glance at Copilot Studio's own Analytics
tab for message-credit consumption — the two billing surfaces don't share one dashboard (see
`docs/cost-analysis.md`). This project's own practice was a check at the close of every
milestone; carry that cadence forward rather than waiting for a budget alert to be the first
signal.

## Project teardown

If this platform is ever decommissioned rather than handed off, both CI/CD identities (the
Azure Managed Identity and the Power Platform service principal) hold real standing access
and should be deleted explicitly, not left to expire — along with both Dataverse environments,
the Azure resource group, and the temporary payment card tied to this project's Azure account.
See the project's own teardown notes (kept outside this repo, per this project's practice of
not committing anything account/billing-identifying) for the specific account cleanup steps.
