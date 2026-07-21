"""Thin wrapper over AuditLogRepository — exists so callers depend on a
service (per SPRINT0.md §1.2's cross-module rule) rather than reaching
into another module's repository directly.
"""

from typing import Any
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.audit.models import AuditLog
from app.modules.audit.repository import AuditLogRepository


class AuditService:
    def __init__(self, session: AsyncSession) -> None:
        self._repo = AuditLogRepository(session)

    async def log(
        self,
        action: str,
        *,
        company_id: UUID | None = None,
        user_id: UUID | None = None,
        entity_table: str | None = None,
        entity_id: UUID | None = None,
        before_data: dict[str, Any] | None = None,
        after_data: dict[str, Any] | None = None,
        ip_address: str | None = None,
        device_id: str | None = None,
        user_agent: str | None = None,
    ) -> AuditLog:
        return await self._repo.create(
            action=action,
            company_id=company_id,
            user_id=user_id,
            entity_table=entity_table,
            entity_id=entity_id,
            before_data=before_data,
            after_data=after_data,
            ip_address=ip_address,
            device_id=device_id,
            user_agent=user_agent,
        )

    async def list_login_history(self, user_id: UUID, *, limit: int = 50) -> list[AuditLog]:
        return await self._repo.list_for_user(user_id, limit=limit)
