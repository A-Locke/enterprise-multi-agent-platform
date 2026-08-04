"""Milestone 1 end-to-end auth demo endpoints.

/me shows any authenticated caller their own claims/roles; /admin/ping is gated to
the Admin App Role, demonstrating role-based authorization end-to-end.
"""

from fastapi import APIRouter, Depends

from ..auth import get_current_user, require_role

router = APIRouter()


@router.get("/me")
def me(claims: dict = Depends(get_current_user)) -> dict:
    return {
        "oid": claims.get("oid"),
        "name": claims.get("name"),
        "roles": claims.get("roles", []),
    }


@router.get("/admin/ping")
def admin_ping(claims: dict = Depends(require_role("Admin"))) -> dict:
    return {"message": "pong", "role": "Admin"}
