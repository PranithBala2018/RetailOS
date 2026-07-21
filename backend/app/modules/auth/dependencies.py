"""FastAPI dependencies: authenticate the caller, resolve their tenant
context, and gate endpoints behind RBAC permission checks.
"""

from collections.abc import Awaitable, Callable
from uuid import UUID

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import security
from app.core.db import get_db_session
from app.core.exceptions import PermissionDeniedException, UnauthorizedException
from app.core.tenant_context import TenantContext, set_tenant_context
from app.modules.users_roles_permissions.models import User
from app.modules.users_roles_permissions.repository import UserRepository
from app.modules.users_roles_permissions.service import RBACService

_bearer_scheme = HTTPBearer(auto_error=False)


async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
    session: AsyncSession = Depends(get_db_session),
) -> User:
    if credentials is None:
        raise UnauthorizedException("Missing bearer token")

    try:
        payload = security.decode_token(
            credentials.credentials, expected_type=security.TokenType.ACCESS
        )
    except security.InvalidTokenError as exc:
        raise UnauthorizedException("Invalid or expired access token") from exc

    if payload.company_id is None:
        raise UnauthorizedException("Malformed access token")

    user_repo = UserRepository(session)
    user = await user_repo.get_by_id(UUID(payload.company_id), UUID(payload.sub))
    if user is None or not user.is_active:
        raise UnauthorizedException("Account is no longer active")

    branch_id = UUID(payload.branch_id) if payload.branch_id else None
    set_tenant_context(
        TenantContext(user_id=user.id, company_id=user.company_id, branch_id=branch_id)
    )
    request.state.user_id = str(user.id)
    request.state.company_id = str(user.company_id)

    return user


def require_permission(permission_code: str) -> Callable[..., Awaitable[User]]:
    """`Depends(require_permission("users.create"))` — the endpoint only
    runs if the caller's effective permission set (union across every
    role they hold) contains this code."""

    async def _check(
        user: User = Depends(get_current_user),
        session: AsyncSession = Depends(get_db_session),
    ) -> User:
        codes = await RBACService(session).get_effective_permission_codes(user.id)
        if permission_code not in codes:
            raise PermissionDeniedException(f"You do not have the '{permission_code}' permission")
        return user

    return _check
