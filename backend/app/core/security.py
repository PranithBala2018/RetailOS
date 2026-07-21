"""Password hashing and JWT issuance/verification — foundation only.

Per SPRINT0.md §16: Argon2id for password hashing, short-lived access
tokens + rotating refresh tokens. This module deliberately has no
knowledge of the `users` table (that lands with the Identity module in
Sprint 2) — it only knows how to mint and verify tokens for a given
subject/claim set, and how to hash/verify passwords.
"""

import uuid
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from typing import Any

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError
from pydantic import BaseModel

from app.core.config import Settings, get_settings

_password_hasher = PasswordHasher()


class TokenType(StrEnum):
    ACCESS = "access"
    REFRESH = "refresh"


class TokenPayload(BaseModel):
    sub: str
    """Subject — the authenticated user's id (UUID as string)."""
    company_id: str | None = None
    branch_id: str | None = None
    """The user's currently active branch — set at login (their default)
    and re-issued by POST /auth/switch-branch. Session-level, not a
    permanent user attribute."""
    token_type: TokenType
    jti: str
    iat: datetime
    exp: datetime


class InvalidTokenError(Exception):
    """Raised for any malformed, expired, or wrong-type token."""


def hash_password(plain_password: str) -> str:
    return _password_hasher.hash(plain_password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return _password_hasher.verify(hashed_password, plain_password)
    except (VerifyMismatchError, InvalidHashError):
        return False


def needs_rehash(hashed_password: str) -> bool:
    """True if the stored hash was made with outdated Argon2 parameters."""
    return _password_hasher.check_needs_rehash(hashed_password)


def _create_token(
    *,
    subject: str,
    token_type: TokenType,
    expires_delta: timedelta,
    company_id: str | None = None,
    branch_id: str | None = None,
    settings: Settings,
) -> str:
    now = datetime.now(UTC)
    payload = TokenPayload(
        sub=subject,
        company_id=company_id,
        branch_id=branch_id,
        token_type=token_type,
        jti=str(uuid.uuid4()),
        iat=now,
        exp=now + expires_delta,
    )
    claims: dict[str, Any] = {
        "sub": payload.sub,
        "company_id": payload.company_id,
        "branch_id": payload.branch_id,
        "token_type": payload.token_type.value,
        "jti": payload.jti,
        "iat": int(payload.iat.timestamp()),
        "exp": int(payload.exp.timestamp()),
    }
    return jwt.encode(claims, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def create_access_token(
    subject: str,
    *,
    company_id: str | None = None,
    branch_id: str | None = None,
    settings: Settings | None = None,
) -> str:
    settings = settings or get_settings()
    return _create_token(
        subject=subject,
        token_type=TokenType.ACCESS,
        expires_delta=timedelta(minutes=settings.access_token_expire_minutes),
        company_id=company_id,
        branch_id=branch_id,
        settings=settings,
    )


def create_refresh_token(
    subject: str,
    *,
    company_id: str | None = None,
    branch_id: str | None = None,
    settings: Settings | None = None,
    expires_delta: timedelta | None = None,
) -> str:
    settings = settings or get_settings()
    return _create_token(
        subject=subject,
        token_type=TokenType.REFRESH,
        expires_delta=expires_delta or timedelta(days=settings.refresh_token_expire_days),
        company_id=company_id,
        branch_id=branch_id,
        settings=settings,
    )


def decode_token(
    token: str,
    *,
    expected_type: TokenType | None = None,
    settings: Settings | None = None,
) -> TokenPayload:
    settings = settings or get_settings()
    try:
        raw = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except jwt.PyJWTError as exc:
        raise InvalidTokenError(str(exc)) from exc

    payload = TokenPayload.model_validate(raw)
    if expected_type is not None and payload.token_type != expected_type:
        raise InvalidTokenError(
            f"expected a {expected_type.value} token, got {payload.token_type.value}"
        )
    return payload
