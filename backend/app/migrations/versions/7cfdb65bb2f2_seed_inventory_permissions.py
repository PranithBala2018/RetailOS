"""seed inventory permissions

Revision ID: 7cfdb65bb2f2
Revises: 2990ee6aa213
Create Date: 2026-07-22 09:59:30.305107

"""

import uuid
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op
from app.modules.inventory.permissions_seed import (
    INVENTORY_PERMISSIONS,
    INVENTORY_ROLE_PERMISSIONS,
)

# revision identifiers, used by Alembic.
revision: str = "7cfdb65bb2f2"
down_revision: Union[str, Sequence[str], None] = "2990ee6aa213"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Extends the permission vocabulary seeded in Sprint 2's
# 0abf28a92bd6_seed_default_roles_and_permissions.py and Sprint 3's
# 0a79316d69b0_seed_products_catalog_permissions.py — new codes, linked
# to the *existing* system-default roles (looked up by name).
#
# Idempotent by design (safe to run more than once): every insert is
# guarded by a lookup-first check on the natural key (`permissions.code`,
# the `(role_id, permission_id)` pair on `role_permissions`) rather than
# assuming a fresh table, so re-running this migration against a
# database where it (or part of it) already applied is a no-op rather
# than a duplicate-row error.

permissions_table = sa.table(
    "permissions",
    sa.column("id", sa.UUID()),
    sa.column("code", sa.String()),
    sa.column("module", sa.String()),
    sa.column("screen", sa.String()),
    sa.column("action", sa.String()),
    sa.column("description", sa.String()),
)

role_permissions_table = sa.table(
    "role_permissions",
    sa.column("role_id", sa.UUID()),
    sa.column("permission_id", sa.UUID()),
)


def upgrade() -> None:
    bind = op.get_bind()

    permission_ids: dict[str, uuid.UUID] = {}
    for perm in INVENTORY_PERMISSIONS:
        existing = bind.execute(
            sa.text("SELECT id FROM permissions WHERE code = :code").bindparams(code=perm.code)
        ).fetchone()
        if existing is not None:
            permission_ids[perm.code] = existing[0]
            continue

        perm_id = uuid.uuid4()
        permission_ids[perm.code] = perm_id
        bind.execute(
            permissions_table.insert().values(
                id=perm_id,
                code=perm.code,
                module=perm.module,
                screen=perm.screen,
                action=perm.action.value,
                description=perm.description,
            )
        )

    role_ids: dict[str, uuid.UUID] = {}
    for role_name in INVENTORY_ROLE_PERMISSIONS:
        result = bind.execute(
            sa.text("SELECT id FROM roles WHERE is_system = true AND name = :name").bindparams(
                name=role_name
            )
        ).fetchone()
        if result is None:
            raise RuntimeError(
                f"Expected system role '{role_name}' to already exist "
                "(seeded in a2cce9c09038) — did that migration run?"
            )
        role_ids[role_name] = result[0]

    for role_name, codes in INVENTORY_ROLE_PERMISSIONS.items():
        for code in codes:
            already_linked = bind.execute(
                sa.text(
                    "SELECT 1 FROM role_permissions "
                    "WHERE role_id = :role_id AND permission_id = :permission_id"
                ).bindparams(role_id=role_ids[role_name], permission_id=permission_ids[code])
            ).fetchone()
            if already_linked is not None:
                continue
            bind.execute(
                role_permissions_table.insert().values(
                    role_id=role_ids[role_name],
                    permission_id=permission_ids[code],
                )
            )


def downgrade() -> None:
    bind = op.get_bind()
    codes = [p.code for p in INVENTORY_PERMISSIONS]
    bind.execute(
        sa.text(
            "DELETE FROM role_permissions WHERE permission_id IN "
            "(SELECT id FROM permissions WHERE code = ANY(:codes))"
        ).bindparams(codes=codes)
    )
    bind.execute(sa.text("DELETE FROM permissions WHERE code = ANY(:codes)").bindparams(codes=codes))
