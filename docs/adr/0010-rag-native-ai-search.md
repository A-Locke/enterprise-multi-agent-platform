# ADR-0010: RAG via native Azure AI Search indexing + Copilot Studio native knowledge connection

## Status

Accepted

## Context

Milestone 5 needs real retrieval-augmented generation for the Knowledge Agent scaffolded in
Milestone 4. The original plan assumed a custom pipeline: Azure AI Search + Blob + a
purpose-built Azure Functions ingestion pipeline, exposed as an action to both Semantic Kernel
and Copilot Studio.

Following this project's established preference for Microsoft-native capability over pro-code
where the native option genuinely covers the need (ADR-0009's reasoning applies again here),
two native capabilities cover most of that plan without custom code:

1. **Azure AI Search's own "Import and vectorize data" wizard** — a built-in indexer that
   chunks, embeds (via an Azure OpenAI embedding deployment), and indexes documents directly
   from a Blob container. No custom Functions ingestion pipeline needed for straightforward
   document types (the markdown files used as the corpus here).
2. **Copilot Studio's native "Add knowledge → Azure AI Search" connection** — once an index
   exists, Copilot Studio handles retrieval and grounding itself. No custom connector, no
   Semantic Kernel-side RAG query code needed for the Knowledge Agent's actual question-
   answering path.

This is a bigger simplification than Milestone 4's decision — there, the native option (Connected
Agents) still required real authoring effort. Here, the native option removes an entire planned
pro-code component (the ingestion Functions app) rather than just relocating logic.

## Corpus

This project's own documentation — README, CHANGELOG, PROJECT_JOURNAL, manual-setup.md,
`docs/security-model.md`, `docs/cost-analysis.md`, and all ADRs (~20,000 words as of this
milestone). Zero copyright risk (fully owned), directly relevant (the Knowledge Agent can
answer real questions about this project's own architecture decisions), and grows naturally
as the project continues — no external sourcing needed. Microsoft Learn documentation (CC BY
4.0, confirmed via the `azure-docs` GitHub repo's `LICENSE` file) was considered as a
supplementary external source but not pursued now; revisit if a broader external corpus is
ever needed.

## A second exception to the zero-secrets posture

Free (F0) tier Azure AI Search — the only tier that keeps this milestone at $0, per ADR-0002's
cost policy (Basic tier, the next step up, runs ~€75/month, wildly out of proportion to
every other cost in this project) — **does not support managed identity for its outbound
connection to Blob Storage**. That connection requires a storage account key.

Accepted explicitly, following the same reasoning and precedent as
[ADR-0007](0007-copilot-connector-client-secret.md)'s client secret: a scoped credential
stored in Key Vault (not a plaintext file, not committed), used only for the one connection
that genuinely can't be secretless on this tier, rather than paying disproportionately more to
preserve architectural purity. This is the second such exception in the project, not a new
pattern — `docs/security-model.md` updated accordingly.

## Decision

1. **Storage account + Blob container** (`infra/modules/knowledge-storage.bicep`) holding the
   corpus — synced from the project's own markdown files.
2. **Embedding model deployment** added to the existing Azure OpenAI resource
   (`infra/modules/ai.bicep`) — needed for AI Search's integrated vectorization skill.
3. **Azure AI Search service, Free (F0) tier** (`infra/modules/ai-search.bicep`), system-
   assigned managed identity granted `Cognitive Services OpenAI User` on the OpenAI resource
   (works fine on F0 — only the Storage connection is key-gated), and the storage account key
   stored in Key Vault for the one connection that needs it.
4. **Import and vectorize data wizard** (portal-only — no Bicep/CLI surface for configuring
   the actual indexer/skillset pipeline as of this writing) run against the Blob container to
   build the index.
5. **Copilot Studio's native Azure AI Search knowledge connection** wired to the Knowledge
   Agent, replacing its Milestone 4 placeholder instructions.

## Consequences

**Positive:**
- Removes an entire planned pro-code component (custom Functions ingestion) — less to build,
  test, and maintain, while still fully demonstrating the RAG capability end-to-end.
- The corpus choice makes the demo self-referential and genuinely useful rather than generic.
- $0 infrastructure cost for this milestone (F0 tier, same embedding-model usage-based cost as
  any other Azure OpenAI call, covered by the existing credit).

**Negative / accepted trade-offs:**
- Second exception to the zero-secrets posture (storage account key), same class of trade-off
  as ADR-0007, not a new one.
- F0 tier limits: 50 MB storage, 3 indexes, no SLA — fine for a portfolio corpus, would need
  revisiting for anything production-scale.
- The indexer/skillset setup itself is portal-only (no CLI/Bicep surface found for the actual
  vectorization pipeline configuration, only for the Search *service* resource itself) —
  documented in `manual-setup.md`.

## References

- [ADR-0001](0001-microsoft-platform-evaluation.md) — Microsoft Platform Evaluation principle
- [ADR-0007](0007-copilot-connector-client-secret.md) — precedent for accepting a scoped secret exception
- [ADR-0009](0009-copilot-studio-connected-agents.md) — the same native-over-pro-code reasoning applied to Milestone 4
- `docs/cost-analysis.md` — F0 vs. Basic tier cost comparison
