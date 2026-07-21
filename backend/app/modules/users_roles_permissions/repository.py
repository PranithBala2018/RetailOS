"""Data access for User, Role, Permission, and their join tables."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.users_roles_permissions.models import (
    Permission,
    Role,
    RolePermission,
    User,
    UserBranch,
    UserRole,
)


class UserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, company_id: UUID, user_id: UUID) -> User | None:
        stmt = select(User).where(
            User.id == user_id, User.company_id == company_id, User.deleted_at.is_(None)
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        """Not company-scoped — email is the global login identity (see
        User model docstring). Used only by the pre-auth login path."""
        stmt = select(User).where(User.email == email, User.deleted_at.is_(None))
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_for_company(self, company_id: UUID) -> list[User]:
        stmt = (
            select(User)
            .where(User.company_id == company_id, User.deleted_at.is_(None))
            .order_by(User.full_name)
        )
        return list((await self._session.execute(stmt)).scalars().all())

    async def create(self, user: User) -> User:
        self._session.add(user)
        await self._session.flush()
        return user

    async def assign_branches(self, user_id: UUID, branch_ids: list[UUID]) -> None:
        for branch_id in branch_ids:
            self._session.add(UserBranch(user_id=user_id, branch_id=branch_id))
        await self._session.flush()

    async def get_assigned_branch_ids(self, user_id: UUID) -> list[UUID]:
        stmt = select(UserBranch.branch_id).where(UserBranch.user_id == user_id)
        return list((await self._session.execute(stmt)).scalars().all())

    async def assign_roles(self, user_id: UUID, role_ids: list[UUID]) -> None:
        for role_id in role_ids:
            self._session.add(UserRole(user_id=user_id, role_id=role_id))
        await self._session.flush()

    async def get_role_ids(self, user_id: UUID) -> list[UUID]:
        stmt = select(UserRole.role_id).where(UserRole.user_id == user_id)
        return list((await self._session.execute(stmt)).scalars().all())


class RoleRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, role_id: UUID) -> Role | None:
        stmt = select(Role).where(Role.id == role_id, Role.deleted_at.is_(None))
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def get_system_role_by_name(self, name: str) -> Role | None:
        stmt = select(Role).where(
            Role.name == name, Role.company_id.is_(None), Role.deleted_at.is_(None)
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_available_for_company(self, company_id: UUID) -> list[Role]:
        """System defaults (company_id IS NULL) plus this company's own
        custom roles — see the Role model docstring."""
        stmt = select(Role).where(
            (Role.company_id.is_(None)) | (Role.company_id == company_id),
            Role.deleted_at.is_(None),
        )
        return list((await self._session.execute(stmt)).scalars().all())

    async def create(self, role: Role) -> Role:
        self._session.add(role)
        await self._session.flush()
        return role


class PermissionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_all(self) -> list[Permission]:
        stmt = select(Permission).order_by(Permission.module, Permission.code)
        return list((await self._session.execute(stmt)).scalars().all())

    async def get_by_code(self, code: str) -> Permission | None:
        stmt = select(Permission).where(Permission.code == code)
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_codes_for_role(self, role_id: UUID) -> list[str]:
        stmt = (
            select(Permission.code)
            .join(RolePermission, RolePermission.permission_id == Permission.id)
            .where(RolePermission.role_id == role_id)
        )
        return list((await self._session.execute(stmt)).scalars().all())
