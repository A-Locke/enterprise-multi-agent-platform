# API (Milestone 1: auth skeleton)

FastAPI backend. This milestone only implements Entra ID bearer-token authentication and
App-Role authorization (`/health`, `/me`, `/admin/ping`) as an end-to-end auth demo — the
Semantic Kernel orchestration layer is added in Milestone 2.

## Local setup

```powershell
cd apps/api
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements-dev.txt
```

Requires `AZURE_TENANT_ID` and `AZURE_API_APP_CLIENT_ID` in the environment (see root `.env`
via `scripts/load-env.ps1`).

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

## Endpoints

| Route | Auth | Notes |
|---|---|---|
| `GET /health` | none | liveness check |
| `GET /me` | any authenticated user | returns the caller's claims/roles |
| `GET /admin/ping` | requires `Admin` App Role | demonstrates role-gated authorization |

See [`../../scripts/demo-auth.ps1`](../../scripts/demo-auth.ps1) for acquiring a real token
via MSAL device-code flow and calling this API end-to-end.
