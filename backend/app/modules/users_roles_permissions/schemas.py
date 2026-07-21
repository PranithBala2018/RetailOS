"""Pydantic request/response schemas for User, Role, Permission."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field

from app.common.schemas import ORMSchema
from app.modules.users_roles_permissions.models import PermissionAction


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    full_name: str = Field(min_length=1, max_length=200)
    phone: str | None = Field(default=None, max_length=20)
    default_branch_id: UUID | None = None
    assigned_branch_ids: list[UUID] = Field(default_factory=list)
    role_ids: list[UUID] = Field(default_factory=list)


class UserUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=200)
    phone: str | None = Field(default=None, max_length=20)
    profile_photo_url: str | None = Field(default=None, max_length=500)
    default_branch_id: UUID | None = None
    is_active: bool | None = None


class UserRead(ORMSchema):
    id: UUID
    company_id: UUID
    email: str
    phone: str | None
    full_name: str
    profile_photo_url: str | None
    default_branch_id: UUID | None
    is_active: bool
    must_change_password: bool
    last_login_at: datetime | None = None
    version: int


class RoleRead(ORMSchema):
    id: UUID
    company_id: UUID | None
    name: str
    description: str | None
    is_system: bool


class PermissionRead(ORMSchema):
    id: UUID
    code: str
    module: str
    screen: str | None
    action: PermissionAction
    description: str | None
