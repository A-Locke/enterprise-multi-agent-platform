# ADR-0001: Microsoft Platform Evaluation as a governing principle

## Status

Accepted

## Context

The technical brief leaves nearly all implementation decisions to the engineering agent, constrained only to: Bicep for IaC, environment-driven configuration, milestone-based incremental delivery, and a small set of required documents (`manual-setup.md`, `CHANGELOG.md`, `PROJECT_JOURNAL.md`, ADRs, diagrams, etc.).

Within that freedom, two materially different architectures satisfy the brief equally well on paper:

1. A **modern cloud-agnostic-flavored Azure AI app**: custom frontend (e.g., Next.js), custom backend (e.g., FastAPI), a general orchestration SDK, a general-purpose relational database — using Azure mainly as commodity compute/AI hosting.
2. A **Microsoft-platform-native solution**: Power Platform (Power Apps, Power Automate, Dataverse) for the low-code business layer, Copilot Studio for the conversational surface, and Azure pro-code (Semantic Kernel, AI Foundry, APIM, Functions, Service Bus) only where the low-code platform genuinely can't do the job.

This project is explicitly a portfolio piece aligned with a Microsoft AI Consultant role. Option 1 is technically defensible but doesn't demonstrate the specific platform fluency (Power Platform ALM, Copilot Studio agent authoring, Dataverse-as-datastore trade-offs) that a Microsoft consulting engagement actually requires. Option 2 risks the opposite failure mode: reaching for a Microsoft-branded service everywhere regardless of fit, which is exactly the anti-pattern consultants are supposed to avoid.

## Decision

Adopt a standing rule applied at every architectural decision point, not just at project kickoff:

> For each capability (UI, workflow automation, conversational AI, business data, integrations, messaging, APIs, monitoring, deployment), evaluate the relevant Microsoft-native platform service first. If a custom/pro-code implementation is chosen instead, record the trade-off as an ADR rather than defaulting silently.

Concretely, this means:

- Copilot Studio is the primary conversational surface (custom-engine-agent pattern), not an optional add-on to a custom chat UI.
- Power Apps is evaluated before a custom admin console; Power Automate is evaluated before custom workflow code; Dataverse is evaluated before a general-purpose database for business data.
- Where Azure pro-code is used (Semantic Kernel orchestration, APIM, Functions, Service Bus, AI Search), it's because Power Platform's declarative tooling doesn't reach that capability (e.g., multi-step specialized-agent coordination, vector search) — and that reasoning is written down.
- Each milestone's ADR(s) briefly weigh the decision against the Azure Well-Architected Framework pillars (Reliability, Security, Cost Optimization, Operational Excellence, Performance Efficiency), keeping the trade-off discussion short but consistent.

## Consequences

**Positive:**
- The repository's decision history reads as a consulting engagement's architecture rationale, not just a stack choice.
- Two parallel ALM/IaC tracks (Bicep+azd for Azure, `pac`+Power Platform Build Tools for Power Platform) are made explicit early, avoiding a later scramble to bolt on Power Platform deployment automation.

**Negative / accepted trade-offs:**
- More documentation overhead per milestone (an ADR per non-trivial platform choice, not just per module).
- Some capabilities may end up implemented twice conceptually during evaluation (e.g., prototyping both a Power Automate flow and a Service Bus worker) before settling on one — accepted because the evaluation itself is a deliverable, not overhead to be minimized away.
- Local dev/test velocity is slower than a pure pro-code stack would be, since Power Platform environments and Copilot Studio authoring are portal-driven (see `manual-setup.md`) rather than fully local.

## References

- Original brief: [`../../Enterprise_Multi-Agent_AI_Platform_Technical_Task.md`](../../Enterprise_Multi-Agent_AI_Platform_Technical_Task.md)
- [`PROJECT_JOURNAL.md`](../../PROJECT_JOURNAL.md) — Milestone 0
