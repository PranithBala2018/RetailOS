"""Business logic for Company, Branch, Warehouse.

Optimistic concurrency (SPRINT0.md §6 "Optimistic Locking"): every update
takes the client's last-known `version`; the repository issues a
conditional `UPDATE ... WHERE version = :expected` and a zero-row result
means someone else updated it first — raised as `ConflictException`
rather than silently overwriting.
"""

from uuid import UUID, uuid4

from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.db_utils import affected_rows
from app.core.exceptions import ConflictException, NotFoundException, ValidationException
from app.modules.company.models import Branch, Company, Warehouse
from app.modules.company.repository import BranchRepository, CompanyRepository, WarehouseRepository
from app.modules.company.schemas import (
    BranchCreate,
    BranchUpdate,
    CompanyCreate,
    CompanyUpdate,
    WarehouseCreate,
)

DEFAULT_BRANCH_NAME = "Head Office"
DEFAULT_BRANCH_CODE = "HO"
DEFAULT_WAREHOUSE_NAME = "Main Warehouse"
DEFAULT_WAREHOUSE_CODE = "MAIN"


class CompanyService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = CompanyRepository(session)

    async def get(self, company_id: UUID) -> Company:
        company = await self._repo.get_by_id(company_id)
        if company is None:
            raise NotFoundException("Company not found")
        return company

    async def register_new_company(self, data: CompanyCreate) -> Company:
        company = Company(id=uuid4(), **data.model_dump())
        return await self._repo.create(company)

    async def update(self, company_id: UUID, data: CompanyUpdate, expected_version: int) -> Company:
        changes = data.model_dump(exclude_unset=True)
        if not changes:
            return await self.get(company_id)

        stmt = (
            update(Company)
            .where(Company.id == company_id, Company.version == expected_version)
            .values(**changes, version=Company.version + 1)
        )
        result = await self._session.execute(stmt)
        if affected_rows(result) == 0:
            existing = await self._repo.get_by_id(company_id)
            if existing is None:
                raise NotFoundException("Company not found")
            raise ConflictException(
                "Company was modified by someone else. Reload and try again.", field="version"
            )
        await self._session.flush()
        return await self.get(company_id)


class BranchService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = BranchRepository(session)
        self._warehouse_repo = WarehouseRepository(session)

    async def create_default_branch_with_warehouse(
        self, company_id: UUID
    ) -> tuple[Branch, Warehouse]:
        """Every new company gets one branch and one warehouse so it's
        immediately usable — not a placeholder, a real starting branch
        the owner can rename later."""
        branch = Branch(
            id=uuid4(),
            company_id=company_id,
            name=DEFAULT_BRANCH_NAME,
            code=DEFAULT_BRANCH_CODE,
        )
        await self._repo.create(branch)

        warehouse = Warehouse(
            id=uuid4(),
            company_id=company_id,
            branch_id=branch.id,
            name=DEFAULT_WAREHOUSE_NAME,
            code=DEFAULT_WAREHOUSE_CODE,
            is_default=True,
        )
        await self._warehouse_repo.create(warehouse)

        branch.default_warehouse_id = warehouse.id
        await self._session.flush()
        return branch, warehouse

    async def get(self, company_id: UUID, branch_id: UUID) -> Branch:
        branch = await self._repo.get_by_id(company_id, branch_id)
        if branch is None:
            raise NotFoundException("Branch not found")
        return branch

    async def list_for_company(self, company_id: UUID) -> list[Branch]:
        return await self._repo.list_for_company(company_id)

    async def create(self, company_id: UUID, data: BranchCreate) -> Branch:
        if await self._repo.get_by_code(company_id, data.code) is not None:
            raise ValidationException(f"Branch code '{data.code}' is already in use", field="code")
        branch = Branch(id=uuid4(), company_id=company_id, **data.model_dump())
        return await self._repo.create(branch)

    async def update(
        self, company_id: UUID, branch_id: UUID, data: BranchUpdate, expected_version: int
    ) -> Branch:
        changes = data.model_dump(exclude_unset=True)
        if not changes:
            return await self.get(company_id, branch_id)

        stmt = (
            update(Branch)
            .where(
                Branch.id == branch_id,
                Branch.company_id == company_id,
                Branch.version == expected_version,
            )
            .values(**changes, version=Branch.version + 1)
        )
        result = await self._session.execute(stmt)
        if affected_rows(result) == 0:
            existing = await self._repo.get_by_id(company_id, branch_id)
            if existing is None:
                raise NotFoundException("Branch not found")
            raise ConflictException(
                "Branch was modified by someone else. Reload and try again.", field="version"
            )
        await self._session.flush()
        return await self.get(company_id, branch_id)


class WarehouseService:
    def __init__(self, session: AsyncSession) -> None:
        self._repo = WarehouseRepository(session)

    async def list_for_branch(self, company_id: UUID, branch_id: UUID) -> list[Warehouse]:
        return await self._repo.list_for_branch(company_id, branch_id)

    async def create(self, company_id: UUID, data: WarehouseCreate) -> Warehouse:
        warehouse = Warehouse(id=uuid4(), company_id=company_id, **data.model_dump())
        return await self._repo.create(warehouse)
