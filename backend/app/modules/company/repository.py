"""Data access for Company, Branch, Warehouse.

Every method that reads/writes a Branch or Warehouse takes an explicit
`company_id` and filters by it — this is the application-layer tenant
isolation described in docs/adr/0003. `Company` itself has no
`company_id` to filter by; its own `id` *is* the tenant boundary, so
access to it is guarded by the RBAC dependency at the API layer instead
(a user can only ever act on their own `company_id` from the JWT).
"""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.company.models import Branch, Company, Warehouse


class CompanyRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, company_id: UUID) -> Company | None:
        stmt = select(Company).where(Company.id == company_id, Company.deleted_at.is_(None))
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def create(self, company: Company) -> Company:
        self._session.add(company)
        await self._session.flush()
        return company

    async def update(self, company: Company) -> Company:
        company.version += 1
        await self._session.flush()
        return company


class BranchRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, company_id: UUID, branch_id: UUID) -> Branch | None:
        stmt = select(Branch).where(
            Branch.id == branch_id,
            Branch.company_id == company_id,
            Branch.deleted_at.is_(None),
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def get_by_code(self, company_id: UUID, code: str) -> Branch | None:
        stmt = select(Branch).where(
            Branch.company_id == company_id,
            Branch.code == code,
            Branch.deleted_at.is_(None),
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_for_company(self, company_id: UUID) -> list[Branch]:
        stmt = (
            select(Branch)
            .where(Branch.company_id == company_id, Branch.deleted_at.is_(None))
            .order_by(Branch.name)
        )
        return list((await self._session.execute(stmt)).scalars().all())

    async def create(self, branch: Branch) -> Branch:
        self._session.add(branch)
        await self._session.flush()
        return branch

    async def update(self, branch: Branch) -> Branch:
        branch.version += 1
        await self._session.flush()
        return branch


class WarehouseRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, company_id: UUID, warehouse_id: UUID) -> Warehouse | None:
        stmt = select(Warehouse).where(
            Warehouse.id == warehouse_id,
            Warehouse.company_id == company_id,
            Warehouse.deleted_at.is_(None),
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_for_branch(self, company_id: UUID, branch_id: UUID) -> list[Warehouse]:
        stmt = select(Warehouse).where(
            Warehouse.company_id == company_id,
            Warehouse.branch_id == branch_id,
            Warehouse.deleted_at.is_(None),
        )
        return list((await self._session.execute(stmt)).scalars().all())

    async def create(self, warehouse: Warehouse) -> Warehouse:
        self._session.add(warehouse)
        await self._session.flush()
        return warehouse
