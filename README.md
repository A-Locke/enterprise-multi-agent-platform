# Enterprise Multi-Agent AI Platform

A production-shaped, enterprise multi-agent AI platform built on the Microsoft stack: **Copilot Studio** for the conversational surface, **Semantic Kernel** for custom pro-code orchestration, **Power Platform** (Power Apps, Power Automate, Dataverse) for the low-code business layer, and **Azure** (AI Foundry/OpenAI, AI Search, APIM, Container Apps, Functions, Service Bus) for the pro-code backend — all provisioned as code.

See [`Enterprise_Multi-Agent_AI_Platform_Technical_Task.md`](Enterprise_Multi-Agent_AI_Platform_Technical_Task.md) for the original brief.

## Governing principle

For every architectural capability, the Microsoft-native platform service (Power Apps, Power Automate, Dataverse, Copilot Studio, Logic Apps, Azure AI Foundry, etc.) is evaluated before defaulting to a custom pro-code implementation. Where custom wins, the reasoning is recorded as an ADR (see [`docs/adr/`](docs/adr/)). See [`docs/adr/0001-microsoft-platform-evaluation.md`](docs/adr/0001-microsoft-platform-evaluation.md).

## Repository layout

```
/infra                       Bicep modules + azd main.bicep/main.parameters.json (Azure pro-code side)
/apps/api                    FastAPI + Semantic Kernel orchestration backend (behind APIM)
/apps/functions              Azure Functions (ingestion, connector backends)
/apps/web                    Next.js — only where Power Apps evaluation rules it out (documented)
/power-platform/solutions    Dataverse tables, Power Apps app(s), Power Automate flows, exported Copilot Studio agent
/power-platform/pipelines    Power Platform Build Tools pipeline defs, environment variables, connection references
/docs                        architecture, ADRs, diagrams, guides, consulting deliverables
/.github/workflows           Azure CI/CD (azd + OIDC) and Power Platform ALM pipeline
azure.yaml                   azd project configuration
manual-setup.md              Manual steps that cannot be automated, and why
CHANGELOG.md                 Notable changes per Keep a Changelog
PROJECT_JOURNAL.md           Milestone-by-milestone decisions, blockers, resolutions, lessons learned
```

## Status

Foundation milestone (M0) complete — repo scaffold, governing ADRs, and first Azure infrastructure (`rg-dev`, France Central: Key Vault, Container Registry, Log Analytics/App Insights, APIM, Cost Management budget) provisioned and live. Power Platform Dataverse environment also live. Starting Milestone 1 (Identity & Access) next. See [`PROJECT_JOURNAL.md`](PROJECT_JOURNAL.md) for full milestone history and [`docs/adr/`](docs/adr/) for architecture decisions.

## Local prerequisites

| Tool | Purpose |
|---|---|
| [Azure CLI](https://learn.microsoft.com/cli/azure/) | `az login`, resource/role management, backs `azd` |
| [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) | installed via `az bicep install` | compiles/deploys IaC |
| [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) | provisioning + deployment + CI/CD pipeline scaffolding |
| [Power Platform CLI (`pac`)](https://learn.microsoft.com/power-platform/developer/cli/introduction) | Power Platform solutions, environments, connection references |
| Node.js 20+, Python 3.12+, Docker | app runtimes / local containers |
| [GitHub CLI (`gh`)](https://cli.github.com/) | repo/CI automation |

See [`manual-setup.md`](manual-setup.md) for the handful of steps that cannot be scripted, and why.

## Getting started

No application code yet — Milestone 0 delivered infrastructure only. Documentation and diagrams will grow alongside the implementation; see the milestone plan in [`docs/architecture/`](docs/) (added as each milestone lands).

## Local configuration

Copy [`.env.example`](.env.example) to `.env` and fill in real values (subscription/tenant IDs, region, APIM publisher contact, budget alert email — see `manual-setup.md` #1-2 for where these come from). `.env` is gitignored and is the single source of truth for local config; nothing here is hardcoded into source or Bicep defaults.

PowerShell has no native `.env` sourcing, so load it into your session before running `az`/`azd`/`pac` commands:

```powershell
. .\scripts\load-env.ps1
```

Running this also self-installs a **pre-commit hook** (`.githooks/pre-commit`) that reads `.env` fresh on every commit and blocks it if the staged diff contains any real value from it (subscription/tenant IDs, emails, environment URLs, etc.) — defense-in-depth so local configuration can never accidentally reach a commit.
