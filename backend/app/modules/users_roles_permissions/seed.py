"""The seeded permission vocabulary and default role -> permission map.

This is plain data (not a script) so both the Alembic data-migration and
any future admin tooling import the same source of truth instead of
duplicating it. New modules extend the system by adding entries here and
shipping a migration that inserts them — never by letting end users
create permissions through the API (see Permission model docstring).
"""

from dataclasses import dataclass

from app.modules.users_roles_permissions.models import PermissionAction
from app.modules.users_roles_permissions.service import (
    DEFAULT_ROLE_ADMIN,
    DEFAULT_ROLE_CASHIER,
    DEFAULT_ROLE_MANAGER,
    DEFAULT_ROLE_SUPER_ADMIN,
)


@dataclass(frozen=True, slots=True)
class PermissionDef:
    code: str
    module: str
    action: PermissionAction
    screen: str | None = None
    description: str = ""


PERMISSIONS: tuple[PermissionDef, ...] = (
    PermissionDef(
        "company.read", "company", PermissionAction.READ, description="View company profile"
    ),
    PermissionDef(
        "company.update", "company", PermissionAction.UPDATE, description="Edit company profile"
    ),
    PermissionDef(
        "branches.create", "branches", PermissionAction.CREATE, description="Create a branch"
    ),
    PermissionDef("branches.read", "branches", PermissionAction.READ, description="View branches"),
    PermissionDef(
        "branches.update", "branches", PermissionAction.UPDATE, description="Edit a branch"
    ),
    PermissionDef("users.create", "users", PermissionAction.CREATE, description="Create a user"),
    PermissionDef("users.read", "users", PermissionAction.READ, description="View users"),
    PermissionDef("users.update", "users", PermissionAction.UPDATE, description="Edit a user"),
    PermissionDef("users.delete", "users", PermissionAction.DELETE, description="Disable a user"),
    PermissionDef("users.export", "users", PermissionAction.EXPORT, description="Export user list"),
    PermissionDef("roles.read", "roles", PermissionAction.READ, description="View roles"),
    PermissionDef(
        "roles.create", "roles", PermissionAction.CREATE, description="Create a custom role"
    ),
    PermissionDef(
        "permissions.read",
        "permissions",
        PermissionAction.READ,
        description="View permission catalog",
    ),
    PermissionDef(
        "dashboard.read", "dashboard", PermissionAction.READ, description="View the dashboard"
    ),
)

_ALL_CODES = tuple(p.code for p in PERMISSIONS)

# Role -> permission codes. Extend this (and add a migration) as new
# modules ship; nothing here is edited through the API at runtime.
DEFAULT_ROLE_PERMISSIONS: dict[str, tuple[str, ...]] = {
    DEFAULT_ROLE_SUPER_ADMIN: _ALL_CODES,
    DEFAULT_ROLE_ADMIN: (
        "company.read",
        "company.update",
        "branches.create",
        "branches.read",
        "branches.update",
        "users.create",
        "users.read",
        "users.update",
        "users.delete",
        "users.export",
        "roles.read",
        "permissions.read",
        "dashboard.read",
    ),
    DEFAULT_ROLE_MANAGER: (
        "company.read",
        "branches.read",
        "users.read",
        "dashboard.read",
    ),
    DEFAULT_ROLE_CASHIER: ("dashboard.read",),
}
