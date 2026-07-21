"""Append-only audit trail — every mutating action on identity/financial
data, plus login history. Deliberately excludes SoftDeleteMixin,
ConcurrencyMixin, and SyncMixin: an audit log is never updated, never
deleted, and never created offline.
"""

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.common.base_model import Base, IdMixin


class AuditLog(Base, IdMixin):
    __tablename__ = "audit_logs"

    # Both nullable: a failed login against an email with no matching
    # account has no user_id; a failed login has no company_id until a
    # matching user (and therefore company) is found.
    company_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("companies.id"), nullable=True, index=True
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True, index=True
    )

    # e.g. "auth.login.success", "auth.login.failed", "auth.logout",
    # "company.updated", "user.created" — a stable, growing vocabulary,
    # not an enum, since new modules add new actions constantly.
    action: Mapped[str] = mapped_column(String(100), index=True)

    entity_table: Mapped[str | None] = mapped_column(String(100), nullable=True)
    entity_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)

    before_data: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)
    after_data: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)

    ip_address: Mapped[str | None] = mapped_column(String(64), nullable=True)
    device_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(String(500), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
