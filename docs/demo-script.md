# Demo Recording Script

A walkthrough script for recording a demo of this platform — not something this session can
record directly, but structured so each beat maps to a specific, already-verified capability
rather than requiring new setup. Aim for 8–12 minutes; cut ruthlessly rather than rush.

## Before recording

- Confirm the Copilot Studio agent is published and the Preview pane loads cleanly.
- Confirm the Container App is warm (`minReplicas: 1` means it should already be — a cold
  first request would look bad on camera).
- Have the Power Platform admin center and Azure Portal open in separate tabs, signed in as
  the relevant accounts, so switching between them doesn't need a live sign-in during
  recording.
- Pick 2–3 real questions to ask the agent that exercise different paths (see beats below) —
  scripted, not improvised, so the demo doesn't stall waiting for a good example.

## Beat 1 — Open on the architecture, not the UI (30–60s)

Show [`docs/deliverables/executive-overview.md`](deliverables/executive-overview.md)'s
one-slide architecture diagram. State the thesis in one sentence: *"Every capability here was
evaluated against a Microsoft-native service first — this demo shows what stayed native and
where custom code actually earned its place."*

## Beat 2 — Copilot Studio conversation (2–3 min)

In the Copilot Studio Preview pane (or Teams, if published there):
1. Ask a question that hits the **Knowledge** Connected Agent (RAG over the indexed
   corpus) — something with a real, verifiable answer from the source documents.
2. Ask a question that hits the **Enterprise Integration** Connected Agent (e.g., "check my
   Teams messages" or similar) — narrate that this is a native Graph connector, not custom
   code calling the Graph API directly ([ADR-0011](../adr/0011-enterprise-integration-native-connectors.md)).
3. Point out (verbally, don't need to show the XML) that this routing between specialized
   agents is Copilot Studio's Connected Agents pattern, not a custom orchestrator.

## Beat 3 — The pro-code layer, briefly (1–2 min)

Show `apps/api`'s `/agent/chat` endpoint — either a quick `curl`/Postman call against the
deployed Container App, or just the code in `apps/api/app/routers/agent.py`. Narrate: *"This
is the one deliberate pro-code layer — Semantic Kernel behind APIM, used specifically where
Copilot Studio's own orchestration wasn't the right fit."* If time allows, show a request
that gets blocked by Content Safety (a deliberately borderline test message) to demonstrate
the moderation layer live — expect a `400` with `"Message blocked by content safety policy"`.

## Beat 4 — Dataverse and the admin app (2 min)

Open the Power Apps model-driven **Platform Admin Console**. Show:
- The Conversation Audit Log table with real entries from the conversation just had in Beat 2
  (if the audit logging path is wired for the demo tenant — confirm before recording).
- Switching between an Admin-role view and an Agent.User-role view (if two demo accounts are
  available) to show Dataverse's native row-level security in action — no application code
  enforcing this, it's the platform.

## Beat 5 — CI/CD, live (2–3 min)

This is the part most demos skip and shouldn't — it's real, working infrastructure, not a
slide. Either:
- Trigger `azure-dev.yml` or `power-platform-deploy.yml` via `gh workflow run` or the GitHub
  Actions UI, and let it run in the background while narrating the next beat, checking back
  to show it went green.
- Or, if time is short, show the Actions tab's run history — several real, green runs for
  both pipelines — and narrate the OIDC/Application-User authentication model in one sentence
  each ([ADR-0013](../adr/0013-combined-release-process.md)).

## Beat 6 — Close on the documentation trail (30s)

End on `PROJECT_JOURNAL.md` or `docs/adr/` scrolled to show the volume and specificity —
*"Every non-trivial decision and every real bug hit building this is documented here, not
smoothed over."* This is the detail that distinguishes a portfolio piece built like a real
engagement from one built like a demo.

## What to explicitly skip

Don't demo: local `pytest`/`ruff` runs (not visually interesting), the Bicep source itself
(reference it, don't scroll through it live), or anything requiring a second person/account
that isn't confirmed working beforehand. A shorter, clean demo beats a longer one with a dead
pause waiting for something to load or a login that wasn't pre-staged.
