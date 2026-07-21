"""Refresh tokens (doubling as device-session records) and password
reset tokens. Neither carries `company_id` directly — both are auth
artifacts scoped by `user_id`; a company scope is derivable through the
user when needed and wasn't worth duplicating onto every row.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.common.base_model import Base, IdMixin


class RefreshToken(Base, IdMixin):
    """One row per issued refresh token = one device session. Rotation on
    every `/auth/refresh` call chains `replaced_by_token_id` so reuse of
    an already-rotated (and therefore revoked) token is detectable —
    a classic signal of a stolen refresh token.
    """

    __tablename__ = "refresh_tokens"
    __table_args__ = (UniqueConstraint("token_hash", name="uq_refresh_tokens_token_hash"),)

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )
    # SHA-256 hex digest — the raw refresh token is never persisted,
    # only ever sent to the client once, at issuance.
    token_hash: Mapped[str] = mapped_column(String(64), index=True)

    device_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    device_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    ip_address: Mapped[str | None] = mapped_column(String(64), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(String(500), nullable=True)

    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    replaced_by_token_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("refresh_tokens.id", use_alter=True, name="fk_refresh_tokens_replaced_by"),
        nullable=True,
    )


class PasswordResetToken(Base, IdMixin):
    __tablename__ = "password_reset_tokens"
    __table_args__ = (UniqueConstraint("token_hash", name="uq_password_reset_tokens_token_hash"),)

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )
    token_hash: Mapped[str] = mapped_column(String(64), index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
