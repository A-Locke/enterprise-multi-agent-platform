# Enterprise Multi-Agent AI Platform

A production-shaped, enterprise multi-agent AI platform built on the Microsoft stack: **Copilot Studio** for the conversational surface, **Semantic Kernel** for custom pro-code orchestration, **Power Platform** (Power Apps, Power Automate, Dataverse) for the low-code business layer, and **Azure** (OpenAI, AI Search, APIM, Container Apps, Functions, Service Bus) for the pro-code backend — all provisioned as code. Azure AI Foundry was evaluated against a bare Azure OpenAI resource per [ADR-0005](docs/adr/0005-azure-openai-over-ai-foundry.md); the simpler path won for this project's scope.

See [`Enterprise_Multi-Agent_AI_Platform_Technical_Task.md`](Enterprise_Multi-Agent_AI_Platform_Technical_Task.md) for the original brief.

## Governing principle

For every architectural capability, the Microsoft-native platform service (Power Apps, Power Automate, Dataverse, Copilot Studio, Logic Apps, Azure AI Foundry, etc.) is evaluated before defaulting to a custom pro-code implementation. Where custom wins, the reasoning is recorded as an ADR (see [`docs/adr/`](docs/adr/)). See [`docs/adr/0001-microsoft-platform-evaluation.md`](docs/adr/0001-microsoft-platform-evaluation.md).

## Repository layout

```
/infra                       Bicep modules + azd main.bicep/main.parameters.json (Azure pro-code side)
/apps/api                    FastAPI + Semantic Kernel orchestration backend (behind APIM)
/apps/functions              Azure Functions -- scaffolded, ultimately unused: RAG ingestion and enterprise
                              integration both landed on native Power Platform capability instead (ADR-0010, ADR-0011)
/apps/web                    Next.js -- scaffolded, ultimately unused: Power Apps and Copilot Studio covered
                              every user-facing surface this project needed
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

Milestones 0–10 complete. A working enterprise multi-agent platform across both halves of
the Microsoft stack: **Copilot Studio** hosts the primary conversational surface (Connected
Agents pattern, native Teams/Outlook/SharePoint/Planner tools, RAG via Dataverse-indexed
knowledge); **Power Platform** carries the business data layer (Dataverse tables, security
roles, a model-driven admin app) and its own Build Tools promotion pipeline (dev → test);
**Azure** carries the pro-code side (Semantic Kernel behind APIM, Azure OpenAI, AI Search,
Content Safety, Container Apps) with its own GitHub↔Azure OIDC deploy pipeline. Every
non-trivial decision is an ADR (`docs/adr/`); every real bug and its root cause is in
`PROJECT_JOURNAL.md`. See [`docs/deliverables/`](docs/deliverables/) for the consulting-facing
summary (executive overview, cost estimate, roadmap, handover guides).

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
| [`docs/cost-analysis.md`](docs/cost-analysis.md) | Per-resource cost breakdown, free-tier/credit strategy, budget guardrails, actual spend |
| [`docs/observability.md`](docs/observability.md) | Azure Monitor alerts + Power Platform native analytics |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | Symptom-indexed index of every real issue this project hit, linking back to the ADR/journal entry |
| [`docs/adr/`](docs/adr/) | Architecture Decision Records — the reasoning behind every non-trivial choice |
| [`docs/diagrams/`](docs/diagrams/) | Sequence diagrams for major request flows (auth, agent chat) |
| [`docs/deliverables/`](docs/deliverables/) | Consulting-facing artifacts: executive overview, solution proposal, assumptions/constraints, risk register, cost estimate, roadmap, technical + operations handover |
| [`docs/walkthrough-guide.md`](docs/walkthrough-guide.md) | Step-by-step guide to exploring the live platform manually |
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
