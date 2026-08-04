# API (Milestone 2: auth + one working agent)

FastAPI backend. Entra ID bearer-token authentication and App-Role authorization
(`/health`, `/me`, `/admin/ping`) plus one Semantic Kernel agent (`/agent/chat`) calling
Azure OpenAI via managed identity — no API keys anywhere.

## Local setup

```powershell
cd apps/api
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
```

Requires `AZURE_TENANT_ID`, `AZURE_API_APP_CLIENT_ID`, `AZURE_OPENAI_ENDPOINT`, and
`AZURE_OPENAI_DEPLOYMENT_NAME` in the environment (see root `.env` via
`scripts/load-env.ps1`). Calling `/agent/chat` locally also requires `az login` with an
account granted `Cognitive Services OpenAI User` on the Azure OpenAI resource (see
`infra/modules/ai.bicep`'s `localDevPrincipalId` param).

## Run

```powershell
. ..\..\scripts\load-env.ps1
uvicorn app.main:app --reload
```

## Test

```powershell
pytest
ruff check .
mypy app
```

`/agent/chat` is unit-tested with the Semantic Kernel call stubbed
(`tests/test_agent.py`) — no real Azure OpenAI calls in the test suite. Use
`scripts/demo-auth.ps1` for a live end-to-end check against the real model.

## Endpoints

| Route | Auth | Notes |
|---|---|---|
| `GET /health` | none | liveness check |
| `GET /me` | any authenticated user | returns the caller's claims/roles |
| `GET /admin/ping` | requires `Admin` App Role | demonstrates role-gated authorization |
| `POST /agent/chat` | requires `Admin` or `Agent.User` | Semantic Kernel agent, calls Azure OpenAI (`gpt-5-mini`) via managed identity |

See [`../../scripts/demo-auth.ps1`](../../scripts/demo-auth.ps1) for acquiring a real token
via the device-code flow and calling all three protected routes end-to-end, and
[`../../docs/diagrams/agent-chat-sequence.md`](../../docs/diagrams/agent-chat-sequence.md)
for the full `/agent/chat` request path.
