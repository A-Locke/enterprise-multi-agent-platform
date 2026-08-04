# Enterprise Multi-Agent AI Platform

A production-shaped, enterprise multi-agent AI platform built on the Microsoft stack: **Copilot Studio** for the conversational surface, **Semantic Kernel** for custom pro-code orchestration, **Power Platform** (Power Apps, Power Automate, Dataverse) for the low-code business layer, and **Azure** (OpenAI, AI Search, APIM, Container Apps, Functions, Service Bus) for the pro-code backend — all provisioned as code. Azure AI Foundry was evaluated against a bare Azure OpenAI resource per [ADR-0005](docs/adr/0005-azure-openai-over-ai-foundry.md); the simpler path won for this project's scope.

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

Milestones 0–2 complete. Live: Azure infrastructure (Key Vault, Container Registry, Log Analytics/App Insights, Cost Management budget), Power Platform Dataverse environment, an Entra ID-secured API (`apps/api`) with role-based authorization, and — behind APIM — a working Semantic Kernel agent calling Azure OpenAI via managed identity, verified end-to-end against a real token and a real model response. Starting Milestone 3 (Copilot Studio Agent) next. See [`PROJECT_JOURNAL.md`](PROJECT_JOURNAL.md) for full milestone history and [`docs/adr/`](docs/adr/) for architecture decisions.

## Local prerequisites

| Tool | Purpose |
|---|---|
| [Azure CLI](https://learn.microsoft.com/cli/azure/) | `az login`, resource/role management, backs `azd` |
| [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) (via `az bicep install`) | compiles/deploys IaC |
| [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) | provisioning + deployment + CI/CD pipeline scaffolding |
| [Power Platform CLI (`pac`)](https://learn.microsoft.com/power-platform/developer/cli/introduction) | Power Platform solutions, environments, connection references |
| Node.js 20+, Python 3.12+ | app runtimes |
| Docker Desktop (**must be running**, not just installed) | local container builds — `azd deploy`'s remote build is disabled on this subscription, see `manual-setup.md` #8 |
| [GitHub CLI (`gh`)](https://cli.github.com/) | repo/CI automation |

See [`manual-setup.md`](manual-setup.md) for the handful of steps that cannot be scripted, and why.

## Getting started

`apps/api` runs both standalone and deployed behind APIM (see [`apps/api/README.md`](apps/api/README.md)) with one working Semantic Kernel agent. Documentation and diagrams grow alongside the implementation; see [`docs/`](docs/) (added as each milestone lands).

## Documentation

| Doc | Covers |
|---|---|
| [`docs/security-model.md`](docs/security-model.md) | Identity, RBAC, token validation, secrets handling, known limitations — living doc, updated every milestone |
| [`docs/cost-analysis.md`](docs/cost-analysis.md) | Per-resource cost breakdown, free-tier/credit strategy, budget guardrails |
| [`docs/adr/`](docs/adr/) | Architecture Decision Records — the reasoning behind every non-trivial choice |
| [`docs/diagrams/`](docs/diagrams/) | Sequence diagrams for major request flows (auth, agent chat) |
| [`manual-setup.md`](manual-setup.md) | The handful of steps that can't be automated, and why |
| [`PROJECT_JOURNAL.md`](PROJECT_JOURNAL.md) | Milestone-by-milestone decisions, blockers, resolutions, lessons learned |
| [`CHANGELOG.md`](CHANGELOG.md) | Notable changes per milestone |

## Local configuration

Copy [`.env.example`](.env.example) to `.env` and fill in real values (subscription/tenant IDs, region, APIM/budget contacts, Entra app + Power Platform IDs, Azure OpenAI RBAC principal — each documented inline in the file, with a pointer to `manual-setup.md` where the value comes from a manual step). `.env` is gitignored and is the single source of truth for local config; nothing here is hardcoded into source or Bicep defaults.

PowerShell has no native `.env` sourcing, so load it into your session before running `az`/`azd`/`pac` commands:

```powershell
. .\scripts\load-env.ps1
```

Running this also self-installs a **pre-commit hook** (`.githooks/pre-commit`) that reads `.env` fresh on every commit and blocks it if the staged diff contains any real value from it (subscription/tenant IDs, emails, environment URLs, etc.) — defense-in-depth so local configuration can never accidentally reach a commit.
