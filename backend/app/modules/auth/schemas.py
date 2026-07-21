"""Pydantic request/response schemas for authentication."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)
    remember_me: bool = False
    device_id: str | None = Field(default=None, max_length=255)
    device_name: str | None = Field(default=None, max_length=255)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str = Field(min_length=8, max_length=128)


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)


class SwitchBranchRequest(BaseModel):
    branch_id: UUID


class MeResponse(BaseModel):
    user_id: UUID
    company_id: UUID
    branch_id: UUID | None
    email: str
    full_name: str
    permissions: list[str]


class SessionRead(BaseModel):
    id: UUID
    device_id: str | None
    device_name: str | None
    ip_address: str | None
    issued_at: datetime
    expires_at: datetime
    last_used_at: datetime | None
    is_current: bool
