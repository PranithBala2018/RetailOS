"""seed default roles and permissions

Revision ID: 0abf28a92bd6
Revises: a2cce9c09038
Create Date: 2026-07-21 21:05:36.826172

"""

import uuid
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op
from app.modules.users_roles_permissions.seed import DEFAULT_ROLE_PERMISSIONS, PERMISSIONS

# revision identifiers, used by Alembic.
revision: str = "0abf28a92bd6"
down_revision: Union[str, Sequence[str], None] = "a2cce9c09038"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Data-only migration: inserts the fixed permission vocabulary and the
# four system default roles (company_id NULL — shared by every tenant,
# see the Role model docstring), plus the role_permissions bundles
# defined in app/modules/users_roles_permissions/seed.py. Nothing here
# is ever edited through the API at runtime.

permissions_table = sa.table(
    "permissions",
    sa.column("id", sa.UUID()),
    sa.column("code", sa.String()),
    sa.column("module", sa.String()),
    sa.column("screen", sa.String()),
    sa.column("action", sa.String()),
    sa.column("description", sa.String()),
)

roles_table = sa.table(
    "roles",
    sa.column("id", sa.UUID()),
    sa.column("company_id", sa.UUID()),
    sa.column("name", sa.String()),
    sa.column("description", sa.String()),
    sa.column("is_system", sa.Boolean()),
    sa.column("version", sa.Integer()),
)

role_permissions_table = sa.table(
    "role_permissions",
    sa.column("role_id", sa.UUID()),
    sa.column("permission_id", sa.UUID()),
)


def upgrade() -> None:
    bind = op.get_bind()

    permission_ids: dict[str, uuid.UUID] = {}
    for perm in PERMISSIONS:
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
    for role_name in DEFAULT_ROLE_PERMISSIONS:
        role_id = uuid.uuid4()
        role_ids[role_name] = role_id
        bind.execute(
            roles_table.insert().values(
                id=role_id,
                company_id=None,
                name=role_name,
                description=f"System default role: {role_name}",
                is_system=True,
                version=1,
            )
        )

    for role_name, codes in DEFAULT_ROLE_PERMISSIONS.items():
        for code in codes:
            bind.execute(
                role_permissions_table.insert().values(
                    role_id=role_ids[role_name],
                    permission_id=permission_ids[code],
                )
            )

def downgrade() -> None:
    bind = op.get_bind()
    role_names = tuple(DEFAULT_ROLE_PERMISSIONS.keys())
    bind.execute(
        sa.text(
            "DELETE FROM role_permissions WHERE role_id IN "
            "(SELECT id FROM roles WHERE is_system = true AND name = ANY(:names))"
        ).bindparams(names=list(role_names))
    )
    bind.execute(sa.text("DELETE FROM roles WHERE is_system = true AND name = ANY(:names)").bindparams(
        names=list(role_names)
    ))
    permission_codes = [p.code for p in PERMISSIONS]
    bind.execute(
        sa.text("DELETE FROM permissions WHERE code = ANY(:codes)").bindparams(codes=permission_codes)
    )
