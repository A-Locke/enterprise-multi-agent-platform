import time

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient

from app import auth
from app.config import settings
from app.main import app

client = TestClient(app)


@pytest.fixture(scope="module")
def rsa_keys():
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return private_key, private_key.public_key()


@pytest.fixture(autouse=True)
def stub_jwks(monkeypatch, rsa_keys):
    """Replace the real JWKS HTTP lookup with our test key pair's public half."""
    _, public_key = rsa_keys

    class FakeSigningKey:
        key = public_key

    class FakeJWKSClient:
        def get_signing_key_from_jwt(self, token: str) -> FakeSigningKey:
            return FakeSigningKey()

    monkeypatch.setattr(auth, "_get_jwks_client", lambda: FakeJWKSClient())


def make_token(rsa_keys, roles: list[str] | None = None, expired: bool = False) -> str:
    private_key, _ = rsa_keys
    now = int(time.time())
    payload = {
        "iss": settings.issuer,
        "aud": settings.audience,
        "oid": "test-oid",
        "name": "Test User",
        "roles": roles or [],
        "iat": now - 10,
        "exp": now - 1 if expired else now + 3600,
    }
    return jwt.encode(payload, private_key, algorithm="RS256")


def test_health_is_public():
    resp = client.get("/health")
    assert resp.status_code == 200


def test_me_requires_token():
    resp = client.get("/me")
    assert resp.status_code == 401


def test_me_with_valid_token(rsa_keys):
    token = make_token(rsa_keys, roles=["Agent.User"])
    resp = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["roles"] == ["Agent.User"]


def test_admin_ping_forbidden_without_admin_role(rsa_keys):
    token = make_token(rsa_keys, roles=["Agent.User"])
    resp = client.get("/admin/ping", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 403


def test_admin_ping_allowed_with_admin_role(rsa_keys):
    token = make_token(rsa_keys, roles=["Admin"])
    resp = client.get("/admin/ping", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json() == {"message": "pong", "role": "Admin"}


def test_expired_token_rejected(rsa_keys):
    token = make_token(rsa_keys, roles=["Admin"], expired=True)
    resp = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 401


def test_wrong_audience_rejected(rsa_keys):
    private_key, _ = rsa_keys
    now = int(time.time())
    payload = {
        "iss": settings.issuer,
        "aud": "api://some-other-app",
        "roles": ["Admin"],
        "iat": now - 10,
        "exp": now + 3600,
    }
    token = jwt.encode(payload, private_key, algorithm="RS256")
    resp = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 401
