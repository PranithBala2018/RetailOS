"""Data access for RefreshToken (device sessions) and PasswordResetToken."""

import hashlib
from datetime import datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.auth.models import PasswordResetToken, RefreshToken


def hash_token(raw_token: str) -> str:
    """SHA-256 — the raw token is never persisted, only ever sent to the
    client once, at issuance (see RefreshToken model docstring)."""
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()


class RefreshTokenRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_token_hash(self, token_hash: str) -> RefreshToken | None:
        stmt = select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_active_for_user(self, user_id: UUID) -> list[RefreshToken]:
        stmt = (
            select(RefreshToken)
            .where(RefreshToken.user_id == user_id, RefreshToken.revoked_at.is_(None))
            .order_by(RefreshToken.issued_at.desc())
        )
        return list((await self._session.execute(stmt)).scalars().all())

    async def create(
        self,
        *,
        user_id: UUID,
        raw_token: str,
        expires_at: datetime,
        device_id: str | None,
        device_name: str | None,
        ip_address: str | None,
        user_agent: str | None,
    ) -> RefreshToken:
        token = RefreshToken(
            user_id=user_id,
            token_hash=hash_token(raw_token),
            expires_at=expires_at,
            device_id=device_id,
            device_name=device_name,
            ip_address=ip_address,
            user_agent=user_agent,
        )
        self._session.add(token)
        await self._session.flush()
        return token

    async def revoke(self, token: RefreshToken, *, revoked_at: datetime) -> None:
        token.revoked_at = revoked_at
        await self._session.flush()

    async def revoke_all_for_user(self, user_id: UUID, *, revoked_at: datetime) -> None:
        for token in await self.list_active_for_user(user_id):
            token.revoked_at = revoked_at
        await self._session.flush()


class PasswordResetTokenRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_token_hash(self, token_hash: str) -> PasswordResetToken | None:
        stmt = select(PasswordResetToken).where(PasswordResetToken.token_hash == token_hash)
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def create(
        self, *, user_id: UUID, raw_token: str, expires_at: datetime
    ) -> PasswordResetToken:
        token = PasswordResetToken(
            user_id=user_id, token_hash=hash_token(raw_token), expires_at=expires_at
        )
        self._session.add(token)
        await self._session.flush()
        return token

    async def mark_used(self, token: PasswordResetToken, *, used_at: datetime) -> None:
        token.used_at = used_at
        await self._session.flush()
