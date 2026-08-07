# Technical Handover Guide

For an engineer picking up this codebase cold. Points to the authoritative source for each
topic rather than duplicating it — this doc is a map, not the territory.

## Start here

1. **Read [`README.md`](../../README.md)** for the repo layout and local prerequisites.
2. **Read `manual-setup.md`** before trying to reproduce this environment from scratch — it
   lists every step that genuinely can't be scripted, and why (tenant/subscription creation,
   the Power Platform region-picker quirk, Copilot Studio licensing, OIDC trust verification).
3. **Skim `docs/adr/` in order.** Fifteen ADRs, each one a real decision with its reasoning —
   reading them in sequence tells the architecture's story better than a diagram alone would.
4. **Skim `PROJECT_JOURNAL.md`.** Every real bug this project hit, root-caused, in
   chronological order. If something breaks that looks unfamiliar, check
   [`docs/troubleshooting.md`](../troubleshooting.md) (symptom-indexed) before re-diagnosing
   from scratch — there's a real chance it's already been hit and solved once.

## Repo layout

See the table in [`README.md`](../../README.md#repository-layout). Two things worth knowing
that aren't obvious from the folder names alone: `apps/functions` and `apps/web` exist but are
empty — both were evaluated and deliberately not built (native Power Platform capability
covered the need each time, see ADR-0010/0011). Don't assume they're just unfinished.

## Local development

```powershell
. .\scripts\load-env.ps1    # loads .env into the session, self-installs the pre-commit hook
```

`.env.example` documents every variable, inline, with a pointer to how/where the real value
comes from. Copy it to `.env` (gitignored) and fill in real values before running anything.

`apps/api` runs standalone (`uvicorn app.main:app --reload`) or behind APIM once deployed —
see `apps/api/README.md`. Tests: `pytest -v` (14 tests, all mocking Azure calls — no live
credentials needed to run them). Lint/type-check: `ruff check .` / `mypy app`.

## Infrastructure

`infra/main.bicep` is the entry point (subscription scope), composing modules from
`infra/modules/`. Deploy via `azd provision` (needs Docker running for `azd deploy` — see
`manual-setup.md` #8) or `az deployment sub create --location <region> --template-file
infra/main.bicep --parameters infra/main.parameters.json` if Docker isn't available and
you're only changing infra, not application code.

Every resource uses managed identity / Entra ID RBAC — there are no API keys to rotate for
Azure resources. The one exception is the Copilot Studio connector's OAuth client secret
(Key Vault, see [ADR-0007](../adr/0007-copilot-connector-client-secret.md)) and the Power
Platform CI/CD service principal's secret (also Key Vault) — both documented, both the
deliberate exception rather than the pattern.

## CI/CD

Three workflows, all in `.github/workflows/`:

- **`ci.yml`** — runs on every PR/push to `main`: Bicep validation + lint, API tests,
  `azd provision --preview` (what-if), and a Power Platform solution pack/unpack roundtrip
  check. No live credentials needed for most jobs; the what-if job uses the same OIDC
  identity as the deploy pipeline, scoped read-only in practice (`--preview` never applies).
- **`azure-dev.yml`** — `workflow_dispatch` only (deliberate, not on push). Provisions and
  deploys the Azure side via `azd`, authenticated via GitHub OIDC federated credentials
  against a dedicated Managed Identity.
- **`power-platform-deploy.yml`** — `workflow_dispatch` only. Packs the business-data
  solution as Managed and imports it into the test Dataverse environment, authenticated via a
  dedicated Application User service principal.

Full context on why both pipelines look the way they do, including every real bug hit
building them, is in [ADR-0013](../adr/0013-combined-release-process.md).

## Power Platform

The Copilot Studio agent and the Dataverse business-data solution are both captured as
source-controlled solutions under `power-platform/solutions/`. Neither can be *authored* from
scratch outside the maker portal (no CLI surface exists for that yet), but both are fully
reproducible from the captured solution via `pac solution import` /
`scripts/deploy-business-data-solution.ps1` once the initial authoring is done once.

If you need to modify the Dataverse schema: make the change in the maker portal against the
**dev** environment, then re-export/re-unpack per the pattern in ADR-0013 (dual `--packagetype
Both` unpack if you need the change to promote as Managed) and re-run
`power-platform-deploy.yml` to push it to test.

## Where the real complexity lives

If you're extending this platform, the two places most likely to bite you are the same two
that took the longest to get right originally: **Power Platform CI/CD** (Dataverse's
export-time `MissingDependencies` snapshot, managed/unmanaged packaging quirks, Application
User setup) and **Azure OIDC in CI specifically** (`azd`'s environment-state behavior differs
between local/interactive and CI/federated-credential auth in several non-obvious ways). Both
are fully documented in ADR-0013 — read it before assuming a CI/CD failure is something new.
