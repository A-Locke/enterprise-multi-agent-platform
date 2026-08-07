# Solution Proposal

## Problem statement

An enterprise wants a multi-agent AI platform: a conversational surface for end users, access
to internal knowledge and enterprise systems (Teams, Outlook, SharePoint), a governed business
data layer, and the ability to promote changes through Dev/Test/Prod like any other production
system — all without defaulting to a fully custom pro-code build that ignores the Microsoft
platform investment the organization has likely already made.

## Approach

**Evaluate Microsoft-native first, at every layer** (the governing principle behind every
decision in this build — [ADR-0001](../adr/0001-microsoft-platform-evaluation.md)). Concretely:

| Layer | Native option evaluated | Outcome |
|---|---|---|
| Conversational surface | Copilot Studio | **Adopted** — Connected Agents pattern, generative orchestration, native Tools |
| Multi-agent coordination | Copilot Studio Connected Agents | **Adopted** — see [ADR-0009](../adr/0009-copilot-studio-connected-agents.md) |
| Knowledge retrieval (RAG) | AI Search integrated vectorization + Dataverse knowledge source | **Adopted** — see [ADR-0010](../adr/0010-rag-native-ai-search.md) |
| Enterprise integration (Teams/Outlook/SharePoint) | Copilot Studio native connectors | **Adopted** — see [ADR-0011](../adr/0011-enterprise-integration-native-connectors.md) |
| Business data | Dataverse | **Adopted** — see [ADR-0012](../adr/0012-dataverse-business-data.md) |
| Admin console | Power Apps model-driven app | **Adopted** — row-level security enforced natively, zero custom authorization code |
| Workflow automation (async/background) | Power Automate / Logic Apps / Service Bus | **Evaluated, not needed** — every actual scenario was an in-conversation agent action, not a background process ([ADR-0011](../adr/0011-enterprise-integration-native-connectors.md)) |
| Custom orchestration | Semantic Kernel behind APIM | **Adopted where native orchestration alone wasn't sufficient** — the one deliberate pro-code layer in this platform |
| Reporting/analytics | Microsoft Fabric / Power BI | **Evaluated, not needed** — Azure Monitor + Power Platform's own native analytics covered the actual need |
| Data governance | Microsoft Purview | **Evaluated, not needed** at this scale — Dataverse security roles + Azure RBAC covered it |
| Content moderation | Azure AI Content Safety | **Adopted** — [ADR-0014](../adr/0014-content-safety.md), layered alongside Copilot Studio's own platform moderation |
| ALM / release | `azd` + OIDC (Azure), Power Platform Build Tools (Power Platform) | **Adopted, both** — two independent, platform-native pipelines, not one custom deploy script pretending Power Platform is just another Azure resource ([ADR-0013](../adr/0013-combined-release-process.md)) |

The pattern holds throughout: **native won more often than not**, and every place it didn't
(the Semantic Kernel API, Content Safety as a dedicated layer) is a deliberate, documented
choice — not a default.

## What was actually built

- A Copilot Studio agent with Connected Agents for Knowledge and Enterprise Integration,
  published and tested via the Preview pane, wired to Teams/Outlook/SharePoint/Planor tools.
- A Semantic Kernel API (`apps/api`) behind Azure API Management, Entra ID-authenticated
  (App Roles: Admin/Agent.User/Auditor), calling Azure OpenAI and Azure AI Content Safety via
  managed identity — no API keys anywhere in the platform.
- Dataverse tables (Agent Configuration, Conversation Audit Log), three mirrored security
  roles, and a Power Apps model-driven admin console — all captured as a source-controlled
  solution and reproducible from a clean environment.
- Azure AI Search (RAG) over a Blob-stored knowledge corpus, integrated vectorization via the
  same Azure OpenAI embedding deployment.
- Azure Monitor alerting (Container App restart spikes, APIM failures) and a documented,
  symptom-indexed troubleshooting reference built from every real issue hit along the way.
- Two independently working, verified-live CI/CD pipelines: GitHub Actions → Azure (OIDC,
  `azd`) and GitHub Actions → Power Platform (Build Tools, `pac`, a dedicated Application
  User), each promoting into a real target environment, not a simulated one.

## What this proves for a consulting engagement

A team inheriting this platform gets: a working reference for how far Copilot Studio and
Power Platform genuinely carry an enterprise AI use case before custom code is needed, a real
example of the two ALM pipelines a hybrid low-code/pro-code Microsoft platform actually needs
(not one pipeline pretending to be both), and a documentation trail — ADRs, a full incident
journal, a troubleshooting index — that reads like the output of a real engagement rather than
a curated demo.
