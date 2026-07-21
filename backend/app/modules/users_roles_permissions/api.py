from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.response import success_envelope
from app.core.db import get_db_session
from app.modules.auth.dependencies import require_permission
from app.modules.users_roles_permissions.models import User
from app.modules.users_roles_permissions.schemas import (
    PermissionRead,
    RoleRead,
    UserCreate,
    UserRead,
    UserUpdate,
)
from app.modules.users_roles_permissions.service import (
    PermissionService,
    RoleService,
    UserService,
)

router = APIRouter(tags=["users"])


class AdminResetPasswordRequest(BaseModel):
    new_password: str


@router.get("/users")
async def list_users(
    current_user: User = Depends(require_permission("users.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    users = await UserService(session).list_for_company(current_user.company_id)
    return success_envelope(
        data=[UserRead.model_validate(u).model_dump(mode="json") for u in users]
    )


@router.post("/users")
async def create_user(
    data: UserCreate,
    current_user: User = Depends(require_permission("users.create")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    user = await UserService(session).create(current_user.company_id, data)
    return success_envelope(
        data=UserRead.model_validate(user).model_dump(mode="json"), message="User created"
    )


@router.get("/users/{user_id}")
async def get_user(
    user_id: UUID,
    current_user: User = Depends(require_permission("users.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    user = await UserService(session).get(current_user.company_id, user_id)
    return success_envelope(data=UserRead.model_validate(user).model_dump(mode="json"))


@router.put("/users/{user_id}")
async def update_user(
    user_id: UUID,
    data: UserUpdate,
    expected_version: int,
    current_user: User = Depends(require_permission("users.update")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    user = await UserService(session).update(
        current_user.company_id, user_id, data, expected_version
    )
    return success_envelope(
        data=UserRead.model_validate(user).model_dump(mode="json"), message="User updated"
    )


@router.delete("/users/{user_id}")
async def disable_user(
    user_id: UUID,
    current_user: User = Depends(require_permission("users.delete")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    await UserService(session).disable(current_user.company_id, user_id)
    return success_envelope(message="User disabled")


@router.post("/users/{user_id}/reset-password")
async def admin_reset_password(
    user_id: UUID,
    data: AdminResetPasswordRequest,
    current_user: User = Depends(require_permission("users.update")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    await UserService(session).admin_reset_password(
        current_user.company_id, user_id, data.new_password
    )
    return success_envelope(message="Password reset — user must change it at next login")


@router.get("/roles")
async def list_roles(
    current_user: User = Depends(require_permission("roles.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    roles = await RoleService(session).list_available_for_company(current_user.company_id)
    return success_envelope(
        data=[RoleRead.model_validate(r).model_dump(mode="json") for r in roles]
    )


@router.get("/permissions")
async def list_permissions(
    current_user: User = Depends(require_permission("permissions.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    permissions = await PermissionService(session).list_all()
    return success_envelope(
        data=[PermissionRead.model_validate(p).model_dump(mode="json") for p in permissions]
    )
