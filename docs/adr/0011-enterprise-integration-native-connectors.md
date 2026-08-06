# ADR-0011: Enterprise Integration Agent uses native M365 connectors, not custom Graph code

## Status

Accepted

## Context

Milestone 6 needs to give the Enterprise Integration Agent (scaffolded with placeholder
instructions in Milestone 4) real capability against Teams, Outlook, SharePoint, and Planner.
The original plan assumed custom code calling Microsoft Graph directly — either a Semantic
Kernel plugin or an Azure Functions backend, mirroring the platform API pattern from
Milestones 1-3.

Following the same evaluation this project has applied at every milestone (ADR-0001): Power
Platform has long-established, first-party prebuilt connectors for exactly these services —
Office 365 Outlook, Microsoft Teams, SharePoint, Planner — usable as Copilot Studio Tools the
same way the platform's own custom connector was wired in Milestone 3. No custom Graph-calling
code is needed for on-demand, conversational actions.

This also clarifies a scoping question the original plan conflated: "workflow automation"
(Power Automate vs. Logic Apps vs. Service Bus) is really a *different* concern from
"enterprise integration" (Teams/Outlook/SharePoint/Planor access). The former is about
asynchronous, scheduled, or multi-step background processes; the latter is about an agent
taking an action or answering a question *within* a live conversation. This milestone's actual
need — the Enterprise Integration Agent responding to things like "check my Teams messages" —
is squarely the second category.

## Decision

1. Add the **Microsoft Teams** and **Office 365 Outlook** prebuilt connectors as Tools on the
   Enterprise Integration Agent (SharePoint and Planner deferred, not because of any
   limitation found, but because two connectors are enough to prove the pattern before
   expanding it — consistent with this project's incremental-build discipline).
2. Update the agent's instructions (replacing the Milestone 4 placeholder) to describe its
   real capability and reinforce the same subagent discipline established in Milestone 4
   (never reply directly, return findings only).
3. **Power Automate vs. Logic Apps vs. Service Bus** evaluated and documented, not
   implemented: none of this milestone's actual scenarios need an async/background workflow.
   If a future milestone introduces one (e.g., a scheduled digest, an approval chain), this
   ADR's evaluation is the starting point, not a new one.

## Consequences

**Positive:**
- Zero custom code for real Teams/Outlook capability — matches the zero-secrets,
  managed-identity-first posture already established, since these connectors use the same
  per-user delegated OAuth pattern already proven in Milestone 3.
- Consistent with ADR-0009 and ADR-0010's reasoning: this project favors the Microsoft-native
  path when it genuinely covers the need, even when a custom alternative might be more
  familiar to build.
- Keeps the "workflow automation" evaluation honest — documented because the brief asked for
  it, not implemented where nothing in the actual milestone needs it.

**Negative / accepted trade-offs:**
- Prebuilt connectors mean less control over exactly what Graph calls get made compared to
  custom code — acceptable for a portfolio-scope demo, would need revisiting for
  fine-grained production authorization requirements.
- SharePoint and Planner connectors not added in this pass — a real scope reduction, not a
  platform limitation; expand later if the demo needs it.

## References

- [ADR-0001](0001-microsoft-platform-evaluation.md) — Microsoft Platform Evaluation principle
- [ADR-0009](0009-copilot-studio-connected-agents.md) — the same native-over-custom reasoning applied to Milestone 4
- [ADR-0010](0010-rag-native-ai-search.md) — same reasoning applied to Milestone 5, including where it did and didn't hold up in practice
