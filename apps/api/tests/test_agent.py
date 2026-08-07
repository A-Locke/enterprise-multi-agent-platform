import time

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient

from app import auth
from app.config import settings
from app.main import app
from app.routers import agent as agent_router

client = TestClient(app)


@pytest.fixture(scope="module")
def rsa_keys():
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return private_key, private_key.public_key()


@pytest.fixture(autouse=True)
def stub_jwks(monkeypatch, rsa_keys):
    _, public_key = rsa_keys

    class FakeSigningKey:
        key = public_key

    class FakeJWKSClient:
        def get_signing_key_from_jwt(self, token: str) -> FakeSigningKey:
            return FakeSigningKey()

    monkeypatch.setattr(auth, "_get_jwks_client", lambda: FakeJWKSClient())


@pytest.fixture(autouse=True)
def stub_agent_chat(monkeypatch):
    """Never call real Azure OpenAI in unit tests -- stub the Semantic Kernel call."""

    async def fake_chat(message: str) -> str:
        return f"echo: {message}"

    monkeypatch.setattr(agent_router, "agent_chat", fake_chat)


@pytest.fixture(autouse=True)
def stub_check_text(monkeypatch):
    """Never call real Azure AI Content Safety in unit tests -- content_safety.py's own
    block-threshold logic is covered separately in test_content_safety.py."""

    async def fake_check_text(text: str) -> None:
        return None

    monkeypatch.setattr(agent_router, "check_text", fake_check_text)


def make_token(rsa_keys, roles: list[str] | None = None) -> str:
    private_key, _ = rsa_keys
    now = int(time.time())
    payload = {
        "iss": settings.issuer,
        "aud": settings.audience[0],
        "roles": roles or [],
        "iat": now - 10,
        "exp": now + 3600,
    }
    return jwt.encode(payload, private_key, algorithm="RS256")


def test_agent_chat_requires_auth():
    resp = client.post("/agent/chat", json={"message": "hi"})
    assert resp.status_code == 401


def test_agent_chat_forbidden_for_auditor(rsa_keys):
    token = make_token(rsa_keys, roles=["Auditor"])
    resp = client.post(
        "/agent/chat", json={"message": "hi"}, headers={"Authorization": f"Bearer {token}"}
    )
    assert resp.status_code == 403


def test_agent_chat_allowed_for_agent_user(rsa_keys):
    token = make_token(rsa_keys, roles=["Agent.User"])
    resp = client.post(
        "/agent/chat", json={"message": "hi"}, headers={"Authorization": f"Bearer {token}"}
    )
    assert resp.status_code == 200
    assert resp.json() == {"reply": "echo: hi"}


def test_agent_chat_allowed_for_admin(rsa_keys):
    token = make_token(rsa_keys, roles=["Admin"])
    resp = client.post(
        "/agent/chat", json={"message": "hi"}, headers={"Authorization": f"Bearer {token}"}
    )
    assert resp.status_code == 200
