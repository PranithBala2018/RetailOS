"""seed products catalog permissions

Revision ID: 0a79316d69b0
Revises: 554ff24b3859
Create Date: 2026-07-21 23:45:18.161105

"""

import uuid
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op
from app.modules.products_catalog.permissions_seed import (
    PRODUCTS_CATALOG_PERMISSIONS,
    PRODUCTS_CATALOG_ROLE_PERMISSIONS,
)

# revision identifiers, used by Alembic.
revision: str = "0a79316d69b0"
down_revision: Union[str, Sequence[str], None] = "554ff24b3859"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Extends the permission vocabulary seeded in Sprint 2's
# 0abf28a92bd6_seed_default_roles_and_permissions.py — new codes, linked
# to the *existing* system-default roles (looked up by name; they
# already exist from that earlier migration, not recreated here).

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
    for perm in PRODUCTS_CATALOG_PERMISSIONS:
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
    for role_name in PRODUCTS_CATALOG_ROLE_PERMISSIONS:
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

    for role_name, codes in PRODUCTS_CATALOG_ROLE_PERMISSIONS.items():
        for code in codes:
            bind.execute(
                role_permissions_table.insert().values(
                    role_id=role_ids[role_name],
                    permission_id=permission_ids[code],
                )
            )


def downgrade() -> None:
    bind = op.get_bind()
    codes = [p.code for p in PRODUCTS_CATALOG_PERMISSIONS]
    bind.execute(
        sa.text(
            "DELETE FROM role_permissions WHERE permission_id IN "
            "(SELECT id FROM permissions WHERE code = ANY(:codes))"
        ).bindparams(codes=codes)
    )
    bind.execute(sa.text("DELETE FROM permissions WHERE code = ANY(:codes)").bindparams(codes=codes))
