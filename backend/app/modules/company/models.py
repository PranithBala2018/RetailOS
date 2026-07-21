"""Company, Branch, and Warehouse — the organizational root of every
tenant. See SPRINT0.md §5, §15 and docs/adr/0003 for the tenant-scoping
rules these tables intentionally do or don't follow.
"""

import uuid
from decimal import Decimal

from sqlalchemy import ForeignKey, Numeric, String, Text
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


class Company(
    Base, IdMixin, TimestampMixin, SoftDeleteMixin, ConcurrencyMixin, SyncMixin, AuditMixin
):
    """The tenant root. Deliberately has no `company_id` of its own — see
    `CompanyScopedMixin`'s docstring in app/common/base_model.py."""

    __tablename__ = "companies"

    name: Mapped[str] = mapped_column(String(200))
    brand_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    logo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    gst_number: Mapped[str | None] = mapped_column(String(20), nullable=True)
    pan: Mapped[str | None] = mapped_column(String(20), nullable=True)

    address_line: Mapped[str | None] = mapped_column(String(500), nullable=True)
    city: Mapped[str | None] = mapped_column(String(100), nullable=True)
    state: Mapped[str | None] = mapped_column(String(100), nullable=True)
    country: Mapped[str | None] = mapped_column(String(100), nullable=True)
    pincode: Mapped[str | None] = mapped_column(String(20), nullable=True)

    mobile: Mapped[str | None] = mapped_column(String(20), nullable=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    website: Mapped[str | None] = mapped_column(String(255), nullable=True)

    currency: Mapped[str] = mapped_column(String(3), default="INR")
    timezone: Mapped[str] = mapped_column(String(50), default="Asia/Kolkata")
    financial_year_start_month: Mapped[int] = mapped_column(default=4)

    invoice_prefix: Mapped[str | None] = mapped_column(String(20), default="INV")
    invoice_footer: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Simplified single default rate — superseded by the full `tax_rates` /
    # `tax_rules` tables when the gst_tax module ships (SPRINT0.md §5.2).
    default_tax_percent: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)

    is_active: Mapped[bool] = mapped_column(default=True)


class Branch(
    Base,
    IdMixin,
    CompanyScopedMixin,
    TimestampMixin,
    SoftDeleteMixin,
    ConcurrencyMixin,
    SyncMixin,
    AuditMixin,
):
    """A branch does not use `BranchScopedMixin` — a branch isn't scoped
    to another branch, it's what that column would point to."""

    __tablename__ = "branches"

    name: Mapped[str] = mapped_column(String(200))
    code: Mapped[str] = mapped_column(String(50))

    address_line: Mapped[str | None] = mapped_column(String(500), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    gst_number: Mapped[str | None] = mapped_column(String(20), nullable=True)

    # Both nullable, both back-references resolved after their target
    # table exists — `use_alter` breaks the branches<->users<->warehouses
    # creation-order cycle by emitting these as separate ALTER TABLE
    # statements instead of inline constraints.
    default_warehouse_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("warehouses.id", use_alter=True, name="fk_branches_default_warehouse_id"),
        nullable=True,
    )
    manager_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", use_alter=True, name="fk_branches_manager_user_id"),
        nullable=True,
    )

    is_active: Mapped[bool] = mapped_column(default=True)


class Warehouse(
    Base,
    IdMixin,
    CompanyScopedMixin,
    TimestampMixin,
    SoftDeleteMixin,
    ConcurrencyMixin,
    SyncMixin,
    AuditMixin,
):
    """Organizational container only — no stock/quantity tracking here.
    That's real Inventory-module scope (out of scope this sprint); this
    table exists now purely so `branches.default_warehouse_id` and future
    stock tables have a real target instead of a placeholder string
    column, per the Sprint 2 brief's "without database redesign" goal.
    """

    __tablename__ = "warehouses"

    branch_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("branches.id"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(200))
    code: Mapped[str] = mapped_column(String(50))
    is_default: Mapped[bool] = mapped_column(default=False)
    is_active: Mapped[bool] = mapped_column(default=True)
