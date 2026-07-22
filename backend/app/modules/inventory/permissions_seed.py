"""New permission codes for the Inventory module, plus which of the
Sprint 2 default roles get them. Same pattern as
`products_catalog/permissions_seed.py` — extending the vocabulary via a
new migration rather than editing already-shipped seed data.

Role assignment follows the Sprint 3 precedent (Manager gets full read
plus additive/reversible actions, not ones that silently overwrite
recorded state): Manager gets read/stock_in/stock_out/transfer — all
three leave an unambiguous ledger trail of what physically moved and
why — but not `adjust`, which overwrites a recorded quantity with no
visible "this was overwritten" marker beyond the ledger row itself, so
it stays as gated as `products.delete`/`products.import` were.
"""

from dataclasses import dataclass

from app.modules.users_roles_permissions.models import PermissionAction
from app.modules.users_roles_permissions.service import (
    DEFAULT_ROLE_ADMIN,
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


INVENTORY_PERMISSIONS: tuple[PermissionDef, ...] = (
    PermissionDef(
        "inventory.read", "inventory", PermissionAction.READ, description="View stock and history"
    ),
    PermissionDef(
        "inventory.stock_in",
        "inventory",
        PermissionAction.CREATE,
        description="Record stock received",
    ),
    PermissionDef(
        "inventory.stock_out",
        "inventory",
        PermissionAction.CREATE,
        description="Record stock removed",
    ),
    PermissionDef(
        "inventory.transfer",
        "inventory",
        PermissionAction.CREATE,
        description="Transfer stock between warehouses",
    ),
    PermissionDef(
        "inventory.adjust",
        "inventory",
        PermissionAction.APPROVE,
        description="Correct a stock count after a physical recount",
    ),
)

_ALL_CODES = tuple(p.code for p in INVENTORY_PERMISSIONS)

INVENTORY_ROLE_PERMISSIONS: dict[str, tuple[str, ...]] = {
    DEFAULT_ROLE_SUPER_ADMIN: _ALL_CODES,
    DEFAULT_ROLE_ADMIN: _ALL_CODES,
    DEFAULT_ROLE_MANAGER: (
        "inventory.read",
        "inventory.stock_in",
        "inventory.stock_out",
        "inventory.transfer",
    ),
}
