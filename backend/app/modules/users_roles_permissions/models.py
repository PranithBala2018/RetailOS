"""Users, Roles, Permissions, and the join tables between them.

RBAC shape, per the Sprint 2 brief: a permission is a code-defined
capability (`module.action`, optionally scoped to a `screen`); a role is
a named bundle of permissions, either a system default (`company_id` is
NULL, shared by every tenant) or a company-specific custom role; a user
can hold multiple roles and is assigned to multiple branches.
"""

import uuid
from datetime import datetime
from enum import StrEnum

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.common.base_model import (
    AuditMixin,
    Base,
    CompanyScopedMixin,
    ConcurrencyMixin,
    IdMixin,
    SoftDeleteMixin,
    SyncMixin,
    TimestampMixin,
)


class PermissionAction(StrEnum):
    """Covers "CRUD, Export, Import, Approval" from the Sprint 2 brief."""

    CREATE = "create"
    READ = "read"
    UPDATE = "update"
    DELETE = "delete"
    EXPORT = "export"
    IMPORT = "import"
    APPROVE = "approve"


class User(
    Base,
    IdMixin,
    CompanyScopedMixin,
    TimestampMixin,
    SoftDeleteMixin,
    ConcurrencyMixin,
    SyncMixin,
    AuditMixin,
):
    __tablename__ = "users"
    __table_args__ = (UniqueConstraint("email", name="uq_users_email"),)

    # Globally unique, not company-scoped: one email is one login
    # identity. A person working across multiple companies gets a
    # separate account per company in Sprint 2 — true multi-company-per-
    # login is a future extension (SPRINT0.md "Future Expansion"), not
    # this sprint's concern.
    email: Mapped[str] = mapped_column(String(255), index=True)
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    full_name: Mapped[str] = mapped_column(String(200))
    password_hash: Mapped[str] = mapped_column(String(255))
    profile_photo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    default_branch_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("branches.id", use_alter=True, name="fk_users_default_branch_id"),
        nullable=True,
    )

    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    must_change_password: Mapped[bool] = mapped_column(Boolean, default=False)

    failed_login_attempts: Mapped[int] = mapped_column(default=0)
    locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Role(Base, IdMixin, TimestampMixin, SoftDeleteMixin, ConcurrencyMixin, AuditMixin):
    """`company_id` is nullable by design: NULL means a system default
    role (Super Admin / Admin / Manager / Cashier, seeded once, shared by
    every tenant); a real UUID means a company-specific custom role —
    this is what makes the permission system extensible per the brief.
    """

    __tablename__ = "roles"
    __table_args__ = (UniqueConstraint("company_id", "name", name="uq_roles_company_id_name"),)

    company_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("companies.id"), nullable=True, index=True
    )
    name: Mapped[str] = mapped_column(String(100))
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_system: Mapped[bool] = mapped_column(default=False)


class Permission(Base, IdMixin):
    """Code-defined capability vocabulary — seeded by the codebase, never
    created through the API (extended by adding new seed rows as new
    modules ship, not by end users at runtime)."""

    __tablename__ = "permissions"
    __table_args__ = (UniqueConstraint("code", name="uq_permissions_code"),)

    code: Mapped[str] = mapped_column(String(150), index=True)
    module: Mapped[str] = mapped_column(String(100), index=True)
    screen: Mapped[str | None] = mapped_column(String(100), nullable=True)
    # native_enum=False: a VARCHAR + CHECK constraint rather than a
    # Postgres native ENUM type, so adding a new action later is a plain
    # migration instead of an ALTER TYPE dance.
    action: Mapped[PermissionAction] = mapped_column(
        Enum(
            PermissionAction,
            native_enum=False,
            length=20,
            validate_strings=True,
            values_callable=lambda enum_cls: [member.value for member in enum_cls],
        )
    )
    description: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class RolePermission(Base):
    __tablename__ = "role_permissions"

    role_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("roles.id"), primary_key=True
    )
    permission_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("permissions.id"), primary_key=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class UserRole(Base):
    __tablename__ = "user_roles"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True
    )
    role_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("roles.id"), primary_key=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class UserBranch(Base):
    """A user's assigned branches. `default_branch_id` on `User` should
    always be one of a user's rows here — enforced at the service layer
    (see users_roles_permissions/service.py), not by a DB constraint,
    since that would be a cross-table check constraint Postgres can't
    express directly."""

    __tablename__ = "user_branches"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True
    )
    branch_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("branches.id"), primary_key=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
