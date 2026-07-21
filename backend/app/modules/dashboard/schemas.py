from uuid import UUID

from pydantic import BaseModel


class DashboardShellResponse(BaseModel):
    """Infrastructure only, per the Sprint 2 brief — no business metrics
    (sales, inventory, etc.) belong here until their modules exist."""

    company_name: str
    branch_name: str | None
    user_full_name: str
    role_names: list[str]
    api_status: str
    database_status: str
    api_version: str
    company_id: UUID
    branch_id: UUID | None
