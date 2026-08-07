# ADR-0009: Copilot Studio Connected Agents for multi-agent coordination

## Status

Accepted

## Context

Milestone 4 needs specialized agents (a Knowledge/RAG specialist, landing fully in Milestone 5;
an Enterprise-Integration specialist, landing fully in Milestone 6) coordinated behind the
single conversational front door built in Milestone 3. Two places this coordination logic
could live:

**Option A — Copilot Studio Connected Agents.** Split into multiple independently-published
Copilot Studio agents, each specialized, with the main "Enterprise Multi-Agent Platform" agent
delegating to them based on the user's intent. This is Copilot Studio's own documented
multi-agent pattern (`learn.microsoft.com/en-us/microsoft-copilot-studio/guidance/multi-agent-patterns`).

**Option B — pro-code routing inside Semantic Kernel.** Keep Copilot Studio as a thin single
front door (as already built in Milestone 3) and implement specialized routing as plugins/
functions inside `apps/api/app/agent.py`, invisible to Copilot Studio beyond the one connector
it already calls.

Milestone 3 generated substantial, well-documented firsthand evidence that Copilot Studio's
operational surface carries real friction — a four-layer licensing maze (ADR-0008), a preview
managed-identity feature that lost saved state twice (ADR-0007), and several undocumented
platform quirks (ADR-0006 through ADR-0008 collectively). That evidence made Option B's
pitch — sidestep more of that friction — genuinely attractive on pure engineering-effort
grounds, and was the initial recommendation here.

**Explicitly rejected.** This project exists to demonstrate Microsoft AI Consultant
competency — Copilot Studio and the Power Platform specifically, not "an AI backend that
happens to run on Azure." Routing around Copilot Studio's native multi-agent capability into
more comfortable pro-code territory would undercut the actual purpose of the exercise, no
matter how much smoother the pro-code path is. Per [ADR-0001](0001-microsoft-platform-evaluation.md)'s
governing principle, the Microsoft-native option is evaluated first — and here, unlike cases
where the native option is genuinely incapable of the job, Connected Agents can do this job.
The friction already documented this session is exactly the kind of thing worth navigating
and writing up (as ADR-0006/0007/0008 already did), not avoiding.

## Decision

Use **Connected Agents** (Option A):

1. The Milestone 3 agent ("Enterprise Multi-Agent Platform") becomes the **parent orchestrator**
   — the only agent that replies to the user, per Microsoft's "single response principle."
2. Add specialized **child agents** as Connected Agents:
   - A **Knowledge Agent** (Milestone 5 fills in real RAG capability; scaffolded now with a
     placeholder knowledge source/description so the routing pattern can be proven before the
     real capability lands).
   - An **Enterprise-Integration Agent** (Milestone 6 fills in real Microsoft Graph actions;
     same scaffolding approach).
3. Author instructions on both the parent and each child following Microsoft's documented
   best practices (directive language — MUST/NEVER/ONLY — not soft phrasing; subagents
   explicitly told never to reply to the user directly; parent instructions define the full
   invoke → wait → combine → respond pattern explicitly, not just "use child agents").
4. Test with domain-mismatch queries (per Microsoft's own guidance) — not just queries that
   perfectly match one child's domain — before considering the routing pattern proven.
5. The existing `Multi-Agent Platform API` connector/tool stays on the **parent** agent, not
   moved to a child — it's the one piece of custom pro-code integration this project has, and
   it represents the "custom orchestration where Copilot Studio's declarative topics aren't
   sufficient" case from the original architecture plan, not something to duplicate per child.

## Consequences

**Positive:**
- Directly demonstrates Copilot Studio's own multi-agent orchestration model — the more
  relevant, job-application-relevant skill for this project's stated purpose.
- Matches Microsoft's own documented separation-of-concerns criteria: the Knowledge and
  Enterprise-Integration domains are genuinely different in tools/knowledge and (eventually)
  governance/access scope, which is exactly when Microsoft's own guidance recommends
  separate agents over one broad one.
- Every friction point hit while building this (and there will likely be more, given the
  session-long pattern) becomes more real, documented material for the same reason
  ADR-0006/0007/0008 already are.

**Negative / accepted trade-offs:**
- Real operational cost: each additional Connected Agent is one more thing to author, publish,
  and maintain in a platform that's already shown itself to be a licensing/preview-feature
  minefield. Accepted explicitly, not overlooked.
- Multi-agent hand-offs add latency (context switching between agents) compared to a single
  in-process pro-code router — acceptable for a demo/portfolio project, would need
  re-evaluating at real production scale.
- Governance/audit surface grows with each child agent (separate transcripts per Microsoft's
  own guidance) — deferred to Milestone 8 (Observability & Ops) rather than solved now.

## References

- [ADR-0001](0001-microsoft-platform-evaluation.md) — Microsoft Platform Evaluation principle, the deciding factor here
- [ADR-0006](0006-copilot-connector-managed-identity.md), [ADR-0007](0007-copilot-connector-client-secret.md), [ADR-0008](0008-copilot-studio-licensing.md) — the firsthand operational friction this decision explicitly chooses to keep navigating rather than route around
- Microsoft Learn: [Multi-agent orchestration patterns and best practices](https://learn.microsoft.com/en-us/microsoft-copilot-studio/guidance/multi-agent-patterns)
