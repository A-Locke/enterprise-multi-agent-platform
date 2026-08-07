# Platform Walkthrough Guide

A step-by-step guide to examining this platform manually — no screen recording involved, just
what to open, what to click, and what you should see at each stop. Useful both as a personal
verification pass and as a reference for anyone else exploring the repo hands-on.

Each section is independent — skip around, no need to do these in order.

## 1. Copilot Studio conversation

Open the agent in [copilotstudiomanager.microsoft.com](https://copilotstudio.microsoft.com) →
your agent → **Test** (the Preview pane).

- **Ask a knowledge question**: something with a real, verifiable answer from the indexed
  corpus (RAG via AI Search/Dataverse — [ADR-0010](adr/0010-rag-native-ai-search.md)). You
  should get a grounded answer, not a generic one — check it actually reflects the source
  document, not just plausible-sounding text.
- **Ask an enterprise-integration question**: e.g. "check my Teams messages" or similar,
  depending on what's connected. This routes through a native Graph connector
  ([ADR-0011](adr/0011-enterprise-integration-native-connectors.md)), not custom code — you
  may get a consent prompt the first time, which is expected.
- Under the hood, both of the above are separate **Connected Agents**
  ([ADR-0009](adr/0009-copilot-studio-connected-agents.md)) that the parent agent routes to —
  nothing to click to see this, just worth knowing while you're testing.

## 2. The pro-code API, directly

`scripts/demo-auth.ps1` opens your browser for a normal interactive sign-in (authorization
code + PKCE — device-code flow is blocked outright by this tenant's Security Defaults policy,
see `docs/security-model.md`), then calls `/me`, `/admin/ping`, and `/agent/chat` itself —
**dot-source** it (leading `. `) so the token it acquires stays available in your session
afterward, pointed at the deployed API rather than localhost:

```powershell
. .\scripts\load-env.ps1
$fqdn = az containerapp show -g rg-dev -n ca-api-kgeonlpliztq6 --query "properties.configuration.ingress.fqdn" -o tsv
. .\scripts\demo-auth.ps1 -ApiBaseUrl "https://$fqdn"
```

Your browser opens to a normal Microsoft sign-in page; after signing in it redirects to a
local listener the script is waiting on. You'll see all three calls succeed, ending with a
real `/agent/chat` reply. Then, with `$token` still set from that run, send one more request
with a deliberately borderline/harsh message to confirm Content Safety
([ADR-0014](adr/0014-content-safety.md)) is actually intercepting it, not just deployed:

```powershell
Invoke-RestMethod -Method POST -Uri "https://$fqdn/agent/chat" `
  -Headers @{ Authorization = "Bearer $token" } -ContentType "application/json" `
  -Body (@{ message = "<something deliberately harsh>" } | ConvertTo-Json)
```

Expect a `400` with `"Message blocked by content safety policy"` instead of a normal reply.

## 3. Dataverse and the admin app

Open [make.powerapps.com](https://make.powerapps.com), switch to the relevant environment,
and open the **Platform Admin Console** app (or go directly to the **Agent Configuration** /
**Conversation Audit Log** tables under **Tables**).

- If you had a Copilot Studio conversation logged (step 1), check the Conversation Audit Log
  for a matching entry — agent name, timestamp, outcome summary.
- If you have access to more than one demo account, sign in as each and compare what's
  visible — an `Agent.User` should only see their own audit entries, an `Auditor` should see
  everyone's. This is Dataverse's native row-level security, not application code.

## 4. CI/CD pipelines

In the repo's **Actions** tab (or `gh run list`), you should see three workflows with green
run history: `ci.yml` (runs on every PR/push), `azure-dev.yml`, and
`power-platform-deploy.yml` (both `workflow_dispatch`-only). To see one run live rather than
just historical green checkmarks:

```powershell
gh workflow run azure-dev.yml
gh run list --workflow=azure-dev.yml --limit 1
```

Watch it in the Actions UI — provisioning + deployment typically takes a few minutes. Full
context on why these pipelines look the way they do (including every real bug hit building
them) is in [ADR-0013](adr/0013-combined-release-process.md).

## 5. The documentation trail

No clicking required — just worth skimming to get a feel for the depth:

- `PROJECT_JOURNAL.md` — chronological, milestone-by-milestone, every real bug and its root
  cause.
- `docs/adr/` — fourteen Architecture Decision Records, one per non-trivial choice.
- `docs/troubleshooting.md` — the same issues, indexed by symptom instead of chronology.

This is the part that distinguishes a project documented like a real engagement from one
documented like a portfolio showcase — worth pointing people here directly rather than trying
to summarize it secondhand.
