# ADR-0010: RAG via native Azure AI Search indexing + Copilot Studio native knowledge connection

## Status

Partially accepted — see "What actually happened wiring this to Copilot Studio" below. The
Azure-side infrastructure (steps 1-4) is built, deployed, and verified working exactly as
planned. Step 5 (Copilot Studio's native knowledge connection) turned out not to be reachable
from this project's agents at all, for reasons unrelated to anything this ADR got wrong about
the Azure side.

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
   Agent, replacing its Milestone 4 placeholder instructions. *(Planned; not achieved — see
   below.)*

## What actually happened wiring this to Copilot Studio

Steps 1-4 worked as planned, including one real correction along the way: the "Search-to-Storage
needs a key, not managed identity" assumption above turned out to be wrong — the actual blocker
was that the Search service's `authOptions` defaulted to `apiKeyOnly`, which silently made every
RBAC grant on the service ineffective regardless of how long they'd had to propagate (a 403 that
looked exactly like propagation lag for the better part of an hour, until checking the service's
own auth configuration directly showed the real cause). Once `authOptions` was set to allow AAD
auth, the managed-identity grant we'd already made started working immediately, no key needed
after all. The indexer then ran successfully: 154/154 documents, 165 chunks, verified live.

Step 5 — actually connecting this index to the Knowledge Agent — hit a wall this ADR didn't
anticipate: Copilot Studio's "Add knowledge → Azure AI Search" option doesn't exist at all for
agents built on the **GitHub Copilot harness**, which is what every agent in this project runs
on. It's a Standard-harness-only feature, confirmed via Microsoft's own harness documentation,
with no migration path between harnesses for an existing agent — switching would mean rebuilding
the parent orchestrator and both Connected Agents from scratch, discarding most of Milestones 3
and 4's Copilot Studio work for one knowledge-source type. Not pursued.

The fallback — uploading the same files directly as a Copilot Studio native "file upload"
knowledge source, which doesn't depend on harness or on this project's own AI Search resource
at all — got further (needed a separate environment setting, "Dataverse intelligence for
agents and AI experiences," found only after the first attempt failed with
`DataverseUnstructuredSearch failed: 400`) but ultimately also didn't complete: file indexing
sat in "In progress" for several hours, well past Microsoft's own stated "may take several
minutes" expectation, and never reached "Ready." This fallback is a *different*, Dataverse-native
indexing pipeline entirely — unrelated to the AI Search resource used in steps 1-4 — so its
failure is independent evidence that this specific capability ("Dataverse intelligence," labeled
Preview in the tenant settings) isn't yet reliable, not something misconfigured on this project's
side. The maker
Preview's own status detail panel for a stuck file also reliably hung the entire browser,
independently confirmed in both Firefox and Edge — a client-side robustness problem layered on
top of the underlying indexing one.

**Net result**: this project has a real, working, verified RAG pipeline at the Azure
infrastructure level (165 indexed chunks, retrievable via the AI Search REST API directly), and
two independently-failed attempts to surface that capability through Copilot Studio specifically
— one blocked by a hard architectural constraint (harness), one blocked by an apparently-broken
preview feature (Dataverse intelligence indexing). Both are documented platform limitations, not
configuration mistakes caught and fixed elsewhere in this project's pattern. Revisit if Microsoft
ships harness interop or the Dataverse intelligence preview stabilizes.

## Consequences

**Positive:**
- Removes an entire planned pro-code component (custom Functions ingestion) — less to build
  and maintain, and the Azure-side pipeline (Blob → native indexer → AI Search) works exactly
  as designed, independently verifiable via the AI Search REST API regardless of whether
  Copilot Studio can consume it.
- The corpus choice makes the demo self-referential and genuinely useful rather than generic.
- $0 infrastructure cost for this milestone (F0 tier, same embedding-model usage-based cost as
  any other Azure OpenAI call, covered by the existing credit) — confirmed via budget check,
  well under €0.30 total project spend at the time this was built.

**Negative / accepted trade-offs:**
- The Knowledge Agent's actual end-user capability wasn't achieved — real infrastructure, no
  working Copilot Studio consumption of it. A harder trade-off than any prior ADR's "accepted
  limitation" entries, since it means this milestone's user-facing goal isn't met, only its
  infrastructure groundwork.
- The zero-secrets exception (storage account key) turned out to be unnecessary in the end —
  the real fix was the Search service's `authOptions` setting, not a key; managed identity
  handled the actual connection. The key sits unused in Key Vault, harmless but no longer load-
  bearing — worth removing during the eventual project teardown rather than now.
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
