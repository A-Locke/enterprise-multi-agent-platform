# Executive Architecture Overview

*Enterprise Multi-Agent AI Platform — a Microsoft-native reference build*

## What this is

A working multi-agent AI platform that answers a question enterprises building on Microsoft
technology actually ask: **how much of this can Copilot Studio and Power Platform genuinely
carry, and where does custom Azure code earn its place?** Every capability in this platform
was evaluated against a Microsoft-native service first; pro-code was used only where the
native option didn't cover the need, and that trade-off is documented as an ADR every time.

## The one-slide architecture

```
                    ┌─────────────────────────────┐
   End users  ───▶  │      Copilot Studio          │  ◀── primary conversational surface
                    │  (Connected Agents pattern)  │      Teams, web, native M365 tools
                    └───────────────┬───────────────┘
                                    │ custom action (APIM)
                    ┌───────────────▼───────────────┐
                    │   Azure API Management         │
                    └───────────────┬───────────────┘
                                    │
                    ┌───────────────▼───────────────┐
                    │  Semantic Kernel API            │  Container Apps, managed identity
                    │  (Content Safety → Azure OpenAI)│  no API keys anywhere
                    └───────────────┬───────────────┘
                                    │
        ┌───────────────┬──────────┴──────────┬───────────────┐
        ▼               ▼                     ▼               ▼
   Azure OpenAI     AI Search (RAG)      Content Safety    Dataverse
   (gpt-5-mini)     over knowledge docs  (moderation)      (business data,
                                                             audit log, roles)
```

Two independent, Microsoft-native release pipelines keep both halves deployable on demand:
GitHub Actions → Azure via OIDC (no stored Azure secret), and GitHub Actions → Power Platform
Build Tools (dev → test, via a dedicated Application User).

## What it demonstrates

- **Copilot Studio as the real conversational layer**, not a thin wrapper — Connected Agents
  routing to specialized sub-agents, native Teams/Outlook/SharePoint/Planner tools, and
  Dataverse-indexed knowledge retrieval, all without custom orchestration code where the
  platform already does it.
- **Pro-code where it earns its place**: a Semantic Kernel API behind APIM for the one thing
  Copilot Studio's generative orchestration doesn't cover on its own, authenticated
  end-to-end via Entra ID managed identity — zero API keys in the entire platform.
- **Dataverse as a real business datastore**, not a placeholder — tables, row-level security
  roles, a model-driven admin app, and a native audit log wired to real agent conversations.
- **Two independently working CI/CD pipelines**, each using the platform's own native release
  tooling (`azd` + OIDC federated credentials; `pac` + Power Platform Build Tools), verified
  end-to-end via live deployments, not just green checkmarks.
- **A defensible cost story**: every resource choice is evaluated against its free tier first;
  actual spend through Milestone 10 is $0.39 against a $180 monthly guardrail.
- **Honest documentation discipline**: every real bug hit during the build — including several
  genuinely non-obvious Azure/Power Platform CI/CD quirks — is root-caused and recorded, not
  smoothed over. See `PROJECT_JOURNAL.md` and `docs/adr/`.

## Who this is for

Built as a portfolio piece for a Microsoft AI Consultant role, but shaped like the output of
a real engagement: an architecture a client's platform team could actually inherit, not a
demo that only works in a screen recording. See
[`technical-handover.md`](technical-handover.md) and
[`operations-handover.md`](operations-handover.md) for what that inheritance would look like
in practice.

## Where to go next

| Question | Doc |
|---|---|
| "Why this service and not that one?" | [`docs/adr/`](../adr/) — one ADR per non-trivial decision |
| "What would this cost at production scale?" | [`cost-estimate.md`](cost-estimate.md) |
| "What's the biggest risk in this design?" | [`risk-register.md`](risk-register.md) |
| "What's next if this kept going?" | [`roadmap.md`](roadmap.md) |
| "What actually broke, and how was it found?" | `PROJECT_JOURNAL.md` |
