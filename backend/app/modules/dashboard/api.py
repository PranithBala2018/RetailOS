from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.response import success_envelope
from app.core.db import get_db_session
from app.core.tenant_context import get_tenant_context
from app.modules.auth.dependencies import require_permission
from app.modules.company.service import BranchService, CompanyService
from app.modules.dashboard.schemas import DashboardShellResponse
from app.modules.users_roles_permissions.models import User
from app.modules.users_roles_permissions.service import RoleService

router = APIRouter(tags=["dashboard"])

API_VERSION = "0.1.0"


@router.get("/dashboard/shell")
async def dashboard_shell(
    current_user: User = Depends(require_permission("dashboard.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    context = get_tenant_context()

    try:
        await session.execute(text("SELECT 1"))
        database_status = "ok"
    except Exception:  # noqa: BLE001 — this is itself the health signal
        database_status = "unreachable"

    company = await CompanyService(session).get(current_user.company_id)
    branch_name = None
    if context.branch_id is not None:
        branch = await BranchService(session).get(current_user.company_id, context.branch_id)
        branch_name = branch.name

    role_names = await RoleService(session).list_names_for_user(current_user.id)

    response = DashboardShellResponse(
        company_name=company.name,
        branch_name=branch_name,
        user_full_name=current_user.full_name,
        role_names=role_names,
        api_status="ok",
        database_status=database_status,
        api_version=API_VERSION,
        company_id=current_user.company_id,
        branch_id=context.branch_id,
    )
    return success_envelope(data=response.model_dump(mode="json"))
