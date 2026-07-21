"""Business logic for User, Role, Permission, and RBAC checks."""

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.db_utils import affected_rows
from app.core.config import Settings, get_settings
from app.core.exceptions import ConflictException, NotFoundException, ValidationException
from app.core.security import hash_password
from app.modules.users_roles_permissions.models import Permission, Role, User
from app.modules.users_roles_permissions.repository import (
    PermissionRepository,
    RoleRepository,
    UserRepository,
)
from app.modules.users_roles_permissions.schemas import UserCreate, UserUpdate

# Seeded once, shared by every company — see Role model docstring.
DEFAULT_ROLE_SUPER_ADMIN = "Super Admin"
DEFAULT_ROLE_ADMIN = "Admin"
DEFAULT_ROLE_MANAGER = "Manager"
DEFAULT_ROLE_CASHIER = "Cashier"
DEFAULT_ROLES = (
    DEFAULT_ROLE_SUPER_ADMIN,
    DEFAULT_ROLE_ADMIN,
    DEFAULT_ROLE_MANAGER,
    DEFAULT_ROLE_CASHIER,
)


class UserService:
    def __init__(self, session: AsyncSession, settings: Settings | None = None) -> None:
        self._session = session
        self._repo = UserRepository(session)
        self._settings = settings or get_settings()

    async def get(self, company_id: UUID, user_id: UUID) -> User:
        user = await self._repo.get_by_id(company_id, user_id)
        if user is None:
            raise NotFoundException("User not found")
        return user

    async def get_by_email_for_login(self, email: str) -> User | None:
        return await self._repo.get_by_email(email)

    async def list_for_company(self, company_id: UUID) -> list[User]:
        return await self._repo.list_for_company(company_id)

    async def create(self, company_id: UUID, data: UserCreate) -> User:
        if await self._repo.get_by_email(data.email) is not None:
            raise ValidationException("Email is already registered", field="email")

        user = User(
            id=uuid4(),
            company_id=company_id,
            email=data.email,
            password_hash=hash_password(data.password),
            full_name=data.full_name,
            phone=data.phone,
            default_branch_id=data.default_branch_id,
        )
        await self._repo.create(user)

        branch_ids = set(data.assigned_branch_ids)
        if data.default_branch_id is not None:
            branch_ids.add(data.default_branch_id)
        if branch_ids:
            await self._repo.assign_branches(user.id, list(branch_ids))
        if data.role_ids:
            await self._repo.assign_roles(user.id, data.role_ids)

        return user

    async def create_owner(self, company_id: UUID, branch_id: UUID, data: UserCreate) -> User:
        """Same as `create`, but always assigned the Super Admin role and
        the newly created default branch — used only by the company
        signup flow (see auth/service.py)."""
        role_repo = RoleRepository(self._session)
        super_admin_role = await role_repo.get_system_role_by_name(DEFAULT_ROLE_SUPER_ADMIN)
        if super_admin_role is None:
            raise RuntimeError(
                "Default roles are not seeded — run the Sprint 2 seed script before signup."
            )
        owner_data = data.model_copy(
            update={
                "default_branch_id": branch_id,
                "assigned_branch_ids": [branch_id],
                "role_ids": [super_admin_role.id],
            }
        )
        return await self.create(company_id, owner_data)

    async def update(
        self, company_id: UUID, user_id: UUID, data: UserUpdate, expected_version: int
    ) -> User:
        changes = data.model_dump(exclude_unset=True)
        if not changes:
            return await self.get(company_id, user_id)

        stmt = (
            update(User)
            .where(
                User.id == user_id, User.company_id == company_id, User.version == expected_version
            )
            .values(**changes, version=User.version + 1)
        )
        result = await self._session.execute(stmt)
        if affected_rows(result) == 0:
            existing = await self._repo.get_by_id(company_id, user_id)
            if existing is None:
                raise NotFoundException("User not found")
            raise ConflictException(
                "User was modified by someone else. Reload and try again.", field="version"
            )
        await self._session.flush()
        return await self.get(company_id, user_id)

    async def disable(self, company_id: UUID, user_id: UUID) -> User:
        user = await self.get(company_id, user_id)
        user.is_active = False
        user.version += 1
        await self._session.flush()
        return user

    async def admin_reset_password(
        self, company_id: UUID, user_id: UUID, new_password: str
    ) -> User:
        """Admin-initiated reset — distinct from the self-service
        forgot/reset-password flow in the auth module. Forces the user
        to pick their own password on next login."""
        user = await self.get(company_id, user_id)
        user.password_hash = hash_password(new_password)
        user.must_change_password = True
        user.version += 1
        await self._session.flush()
        return user

    # --- Login-support methods, called from AuthService (auth module),
    # kept here because they mutate columns that belong to `users`. ---

    async def record_successful_login(self, user: User) -> None:
        user.failed_login_attempts = 0
        user.locked_until = None
        user.last_login_at = datetime.now(UTC)
        await self._session.flush()

    async def record_failed_login(self, user: User) -> None:
        user.failed_login_attempts += 1
        if user.failed_login_attempts >= self._settings.max_failed_login_attempts:
            user.locked_until = datetime.now(UTC) + timedelta(
                minutes=self._settings.account_lockout_minutes
            )
        await self._session.flush()

    def is_locked(self, user: User) -> bool:
        return user.locked_until is not None and user.locked_until > datetime.now(UTC)


class RoleService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = RoleRepository(session)
        self._user_repo = UserRepository(session)

    async def list_available_for_company(self, company_id: UUID) -> list[Role]:
        return await self._repo.list_available_for_company(company_id)

    async def get(self, role_id: UUID) -> Role:
        role = await self._repo.get_by_id(role_id)
        if role is None:
            raise NotFoundException("Role not found")
        return role

    async def list_names_for_user(self, user_id: UUID) -> list[str]:
        role_ids = await self._user_repo.get_role_ids(user_id)
        names = []
        for role_id in role_ids:
            role = await self._repo.get_by_id(role_id)
            if role is not None:
                names.append(role.name)
        return names


class PermissionService:
    def __init__(self, session: AsyncSession) -> None:
        self._repo = PermissionRepository(session)

    async def list_all(self) -> list[Permission]:
        return await self._repo.list_all()


class RBACService:
    """Resolves a user's effective permission set — the union of every
    permission attached to every role the user holds."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._user_repo = UserRepository(session)
        self._permission_repo = PermissionRepository(session)

    async def get_effective_permission_codes(self, user_id: UUID) -> set[str]:
        role_ids = await self._user_repo.get_role_ids(user_id)
        codes: set[str] = set()
        for role_id in role_ids:
            codes.update(await self._permission_repo.list_codes_for_role(role_id))
        return codes
