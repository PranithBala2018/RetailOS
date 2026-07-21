from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.response import success_envelope
from app.core.db import get_db_session
from app.core.tenant_context import get_tenant_context
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.schemas import (
    ChangePasswordRequest,
    ForgotPasswordRequest,
    LoginRequest,
    MeResponse,
    RefreshRequest,
    ResetPasswordRequest,
    SessionRead,
    SwitchBranchRequest,
    TokenResponse,
)
from app.modules.auth.service import AuthService, RequestContext
from app.modules.company.schemas import BranchRead
from app.modules.users_roles_permissions.models import User
from app.modules.users_roles_permissions.service import RBACService

router = APIRouter(prefix="/auth", tags=["auth"])


def _request_context(request: Request) -> RequestContext:
    return RequestContext(
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )


@router.post("/login")
async def login(
    data: LoginRequest, request: Request, session: AsyncSession = Depends(get_db_session)
) -> dict[str, Any]:
    tokens = await AuthService(session).login(data, _request_context(request))
    return success_envelope(
        data=TokenResponse.model_validate(tokens).model_dump(), message="Signed in"
    )


@router.post("/logout")
async def logout(
    data: RefreshRequest, session: AsyncSession = Depends(get_db_session)
) -> dict[str, Any]:
    await AuthService(session).logout(data.refresh_token)
    return success_envelope(message="Signed out")


@router.post("/refresh")
async def refresh(
    data: RefreshRequest, request: Request, session: AsyncSession = Depends(get_db_session)
) -> dict[str, Any]:
    tokens = await AuthService(session).refresh(data.refresh_token, _request_context(request))
    return success_envelope(data=tokens.model_dump(), message="Token refreshed")


@router.post("/forgot-password")
async def forgot_password(
    data: ForgotPasswordRequest, session: AsyncSession = Depends(get_db_session)
) -> dict[str, Any]:
    await AuthService(session).forgot_password(data.email)
    return success_envelope(
        message="If that email is registered, a password reset link has been sent"
    )


@router.post("/reset-password")
async def reset_password(
    data: ResetPasswordRequest, session: AsyncSession = Depends(get_db_session)
) -> dict[str, Any]:
    await AuthService(session).reset_password(data.token, data.new_password)
    return success_envelope(message="Password reset. Please sign in with your new password.")


@router.post("/change-password")
async def change_password(
    data: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    await AuthService(session).change_password(
        current_user, data.current_password, data.new_password
    )
    return success_envelope(message="Password changed")


@router.post("/switch-branch")
async def switch_branch(
    data: SwitchBranchRequest,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    access_token = await AuthService(session).switch_branch(current_user, data.branch_id)
    return success_envelope(data={"access_token": access_token}, message="Branch switched")


@router.get("/my-branches")
async def my_branches(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    """The caller's own assigned branches — not gated behind the
    `branches.read` admin permission, since every role needs to pick a
    branch at login regardless of what they're otherwise allowed to
    manage."""
    branches = await AuthService(session).list_my_branches(current_user)
    return success_envelope(
        data=[BranchRead.model_validate(b).model_dump(mode="json") for b in branches]
    )


@router.get("/me")
async def me(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    context = get_tenant_context()
    permissions = sorted(await RBACService(session).get_effective_permission_codes(current_user.id))
    response = MeResponse(
        user_id=current_user.id,
        company_id=current_user.company_id,
        branch_id=context.branch_id,
        email=current_user.email,
        full_name=current_user.full_name,
        permissions=permissions,
    )
    return success_envelope(data=response.model_dump(mode="json"))


@router.get("/sessions")
async def list_sessions(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    tokens = await AuthService(session).list_sessions(current_user.id)
    reads = [
        SessionRead(
            id=t.id,
            device_id=t.device_id,
            device_name=t.device_name,
            ip_address=t.ip_address,
            issued_at=t.issued_at,
            expires_at=t.expires_at,
            last_used_at=t.last_used_at,
            is_current=False,
        ).model_dump(mode="json")
        for t in tokens
    ]
    return success_envelope(data=reads)


@router.delete("/sessions/{session_id}")
async def revoke_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    await AuthService(session).revoke_session(current_user.id, UUID(session_id))
    return success_envelope(message="Session revoked")
