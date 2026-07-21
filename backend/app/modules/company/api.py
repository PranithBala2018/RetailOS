"""Company/Branch/Warehouse endpoints.

`POST /companies` is the only endpoint here that doesn't require
authentication — it's how a company comes into existence in the first
place (the "Company Setup Wizard" flow): create the company, its default
branch/warehouse, and an owner user in one transaction, then sign that
owner in immediately. Every other endpoint is scoped to the caller's own
`company_id` (from the JWT) — there is no way to read or write another
company's data through this router.
"""

from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.response import success_envelope
from app.core.db import get_db_session
from app.modules.auth.dependencies import require_permission
from app.modules.auth.service import AuthService, RequestContext
from app.modules.company.schemas import (
    BranchCreate,
    BranchRead,
    BranchUpdate,
    CompanyCreate,
    CompanyRead,
    CompanyUpdate,
    WarehouseCreate,
    WarehouseRead,
)
from app.modules.company.service import BranchService, CompanyService, WarehouseService
from app.modules.users_roles_permissions.models import User
from app.modules.users_roles_permissions.schemas import UserCreate
from app.modules.users_roles_permissions.service import UserService

router = APIRouter(tags=["company"])


class CompanySignupRequest(CompanyCreate):
    owner_email: str
    owner_password: str
    owner_full_name: str


def _request_context(request: Request) -> RequestContext:
    return RequestContext(
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )


@router.post("/companies")
async def signup_company(
    data: CompanySignupRequest, request: Request, session: AsyncSession = Depends(get_db_session)
) -> dict[str, Any]:
    company_fields = data.model_dump(exclude={"owner_email", "owner_password", "owner_full_name"})

    company = await CompanyService(session).register_new_company(CompanyCreate(**company_fields))
    branch, warehouse = await BranchService(session).create_default_branch_with_warehouse(
        company.id
    )
    owner = await UserService(session).create_owner(
        company.id,
        branch.id,
        UserCreate(
            email=data.owner_email,
            password=data.owner_password,
            full_name=data.owner_full_name,
        ),
    )
    tokens = await AuthService(session).issue_initial_tokens(owner, _request_context(request))

    return success_envelope(
        data={
            "company": CompanyRead.model_validate(company).model_dump(mode="json"),
            "branch": BranchRead.model_validate(branch).model_dump(mode="json"),
            "warehouse": WarehouseRead.model_validate(warehouse).model_dump(mode="json"),
            "owner_user_id": str(owner.id),
            "access_token": tokens.access_token,
            "refresh_token": tokens.refresh_token,
        },
        message="Company created",
    )


@router.get("/companies/{company_id}")
async def get_company(
    company_id: UUID,
    current_user: User = Depends(require_permission("company.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    company = await CompanyService(session).get(company_id)
    return success_envelope(data=CompanyRead.model_validate(company).model_dump(mode="json"))


@router.put("/companies/{company_id}")
async def update_company(
    company_id: UUID,
    data: CompanyUpdate,
    expected_version: int,
    current_user: User = Depends(require_permission("company.update")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    company = await CompanyService(session).update(company_id, data, expected_version)
    return success_envelope(
        data=CompanyRead.model_validate(company).model_dump(mode="json"), message="Company updated"
    )


@router.get("/branches")
async def list_branches(
    current_user: User = Depends(require_permission("branches.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    branches = await BranchService(session).list_for_company(current_user.company_id)
    return success_envelope(
        data=[BranchRead.model_validate(b).model_dump(mode="json") for b in branches]
    )


@router.post("/branches")
async def create_branch(
    data: BranchCreate,
    current_user: User = Depends(require_permission("branches.create")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    branch = await BranchService(session).create(current_user.company_id, data)
    return success_envelope(
        data=BranchRead.model_validate(branch).model_dump(mode="json"), message="Branch created"
    )


@router.put("/branches/{branch_id}")
async def update_branch(
    branch_id: UUID,
    data: BranchUpdate,
    expected_version: int,
    current_user: User = Depends(require_permission("branches.update")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    branch = await BranchService(session).update(
        current_user.company_id, branch_id, data, expected_version
    )
    return success_envelope(
        data=BranchRead.model_validate(branch).model_dump(mode="json"), message="Branch updated"
    )


@router.get("/branches/{branch_id}/warehouses")
async def list_warehouses(
    branch_id: UUID,
    current_user: User = Depends(require_permission("branches.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    warehouses = await WarehouseService(session).list_for_branch(current_user.company_id, branch_id)
    return success_envelope(
        data=[WarehouseRead.model_validate(w).model_dump(mode="json") for w in warehouses]
    )


@router.post("/branches/{branch_id}/warehouses")
async def create_warehouse(
    branch_id: UUID,
    data: WarehouseCreate,
    current_user: User = Depends(require_permission("branches.update")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    payload = data.model_copy(update={"branch_id": branch_id})
    warehouse = await WarehouseService(session).create(current_user.company_id, payload)
    return success_envelope(
        data=WarehouseRead.model_validate(warehouse).model_dump(mode="json"),
        message="Warehouse created",
    )
