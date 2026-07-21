"""New permission codes for the Products & Catalog module, plus which of
the Sprint 2 default roles get them. Kept separate from
`users_roles_permissions/seed.py` (rather than editing that file's
already-shipped data) since that data was already migrated in Sprint 2 —
extending the vocabulary is itself a new migration, per that module's
seed.py docstring ("extend this... by adding new rows via migration").
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


PRODUCTS_CATALOG_PERMISSIONS: tuple[PermissionDef, ...] = (
    PermissionDef(
        "categories.read", "categories", PermissionAction.READ, description="View categories"
    ),
    PermissionDef(
        "categories.create", "categories", PermissionAction.CREATE, description="Create a category"
    ),
    PermissionDef(
        "categories.update", "categories", PermissionAction.UPDATE, description="Edit a category"
    ),
    PermissionDef("brands.read", "brands", PermissionAction.READ, description="View brands"),
    PermissionDef("brands.create", "brands", PermissionAction.CREATE, description="Create a brand"),
    PermissionDef("brands.update", "brands", PermissionAction.UPDATE, description="Edit a brand"),
    PermissionDef(
        "units.read", "units", PermissionAction.READ, description="View units of measure"
    ),
    PermissionDef(
        "units.create", "units", PermissionAction.CREATE, description="Create a custom unit"
    ),
    PermissionDef("products.read", "products", PermissionAction.READ, description="View products"),
    PermissionDef(
        "products.create", "products", PermissionAction.CREATE, description="Create a product"
    ),
    PermissionDef(
        "products.update", "products", PermissionAction.UPDATE, description="Edit a product"
    ),
    PermissionDef(
        "products.delete", "products", PermissionAction.DELETE, description="Disable a product"
    ),
    PermissionDef(
        "products.export",
        "products",
        PermissionAction.EXPORT,
        description="Export products to CSV",
    ),
    PermissionDef(
        "products.import",
        "products",
        PermissionAction.IMPORT,
        description="Import products from CSV",
    ),
)

_ALL_CODES = tuple(p.code for p in PRODUCTS_CATALOG_PERMISSIONS)

PRODUCTS_CATALOG_ROLE_PERMISSIONS: dict[str, tuple[str, ...]] = {
    DEFAULT_ROLE_SUPER_ADMIN: _ALL_CODES,
    DEFAULT_ROLE_ADMIN: _ALL_CODES,
    DEFAULT_ROLE_MANAGER: (
        "categories.read",
        "brands.read",
        "units.read",
        "products.read",
        "products.create",
        "products.update",
        "products.export",
    ),
    DEFAULT_ROLE_CASHIER: ("products.read",),
}
