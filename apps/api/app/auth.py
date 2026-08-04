"""Entra ID (Microsoft identity platform) bearer token validation and App-Role authorization.

Validates JWT signature against the tenant's JWKS, plus issuer and audience, then
enforces authorization via the `roles` claim (Entra ID App Roles), not custom claims.
"""

from collections.abc import Callable

import jwt
from fastapi import Depends, HTTPException, Request, status
from jwt import PyJWKClient

from .config import settings

_jwks_client: PyJWKClient | None = None


def _get_jwks_client() -> PyJWKClient:
    global _jwks_client
    if _jwks_client is None:
        _jwks_client = PyJWKClient(settings.jwks_uri)
    return _jwks_client


def decode_token(token: str) -> dict:
    """Validate signature, issuer, and audience; return the token claims.

    Split out from get_current_user so tests can stub _get_jwks_client instead
    of making a real network call to the tenant's JWKS endpoint.
    """
    signing_key = _get_jwks_client().get_signing_key_from_jwt(token)
    return jwt.decode(
        token,
        signing_key.key,
        algorithms=["RS256"],
        audience=settings.audience,
        issuer=settings.issuer,
    )


def get_current_user(request: Request) -> dict:
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token"
        )
    token = auth_header.removeprefix("Bearer ").strip()
    try:
        return decode_token(token)
    except jwt.PyJWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid token: {exc}"
        ) from exc


def require_role(role: str) -> Callable[..., dict]:
    """Dependency factory: authenticate, then require `role` in the token's roles claim."""

    def _dependency(claims: dict = Depends(get_current_user)) -> dict:
        if role not in claims.get("roles", []):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail=f"Requires role: {role}"
            )
        return claims

    return _dependency
