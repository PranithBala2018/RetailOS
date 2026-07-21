"""seed default units

Revision ID: 554ff24b3859
Revises: 5e3f8755c736
Create Date: 2026-07-21 23:40:28.795020

"""

import uuid
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op
from app.modules.products_catalog.seed import DEFAULT_UNITS

# revision identifiers, used by Alembic.
revision: str = "554ff24b3859"
down_revision: Union[str, Sequence[str], None] = "5e3f8755c736"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

units_table = sa.table(
    "units",
    sa.column("id", sa.UUID()),
    sa.column("company_id", sa.UUID()),
    sa.column("name", sa.String()),
    sa.column("abbreviation", sa.String()),
    sa.column("is_system", sa.Boolean()),
    sa.column("version", sa.Integer()),
)


def upgrade() -> None:
    bind = op.get_bind()
    for unit in DEFAULT_UNITS:
        bind.execute(
            units_table.insert().values(
                id=uuid.uuid4(),
                company_id=None,
                name=unit.name,
                abbreviation=unit.abbreviation,
                is_system=True,
                version=1,
            )
        )


def downgrade() -> None:
    bind = op.get_bind()
    abbreviations = [u.abbreviation for u in DEFAULT_UNITS]
    bind.execute(
        sa.text(
            "DELETE FROM units WHERE is_system = true AND abbreviation = ANY(:abbrs)"
        ).bindparams(abbrs=abbreviations)
    )
