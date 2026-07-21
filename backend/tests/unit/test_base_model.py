"""No business module exists yet to exercise `TenantScopedModel`, so this
test declares a throwaway mapped class purely to verify the mixin stack
composes into the column set defined in SPRINT0.md §5.1. It never touches
a database — only SQLAlchemy's mapper configuration.
"""

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.common.base_model import Base, TenantScopedModel


class _Widget(Base, TenantScopedModel):
    """Test-only mapped class — not part of the application schema."""

    __tablename__ = "test_widgets"

    name: Mapped[str] = mapped_column(String(100))


def test_tenant_scoped_model_has_expected_columns() -> None:
    columns = {c.name for c in _Widget.__table__.columns}
    assert columns == {
        "id",
        "company_id",
        "branch_id",
        "created_at",
        "updated_at",
        "deleted_at",
        "version",
        "client_uuid",
        "sync_status",
        "created_by",
        "updated_by",
        "name",
    }


def test_id_column_is_uuid_primary_key() -> None:
    id_column = _Widget.__table__.c.id
    assert id_column.primary_key is True


def test_company_id_is_not_nullable_and_indexed() -> None:
    company_id_column = _Widget.__table__.c.company_id
    assert company_id_column.nullable is False
    assert company_id_column.index is True


def test_branch_id_is_nullable() -> None:
    assert _Widget.__table__.c.branch_id.nullable is True


def test_version_defaults_to_one() -> None:
    assert _Widget.__table__.c.version.default.arg == 1


def test_sync_status_defaults_to_synced() -> None:
    assert _Widget.__table__.c.sync_status.default.arg == "synced"


def test_naming_convention_produces_stable_constraint_names() -> None:
    pk_constraint = _Widget.__table__.primary_key
    assert pk_constraint.name == "pk_test_widgets"
