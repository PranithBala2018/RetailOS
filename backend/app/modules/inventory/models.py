"""Stock levels, the immutable movement ledger, and transfer headers.

Every stock mutation (Stock In, Stock Out, Transfer, Adjustment) writes
exactly one `StockTransaction` row per warehouse side affected — Stock
In/Out/Adjustment write one row each, a Transfer writes two (a
`transfer_out` leg from the source warehouse and a `transfer_in` leg to
the destination, both referencing the same `StockTransfer` header via
`transfer_id`). `StockLevel` holds the current balance only; it is never
written directly by a client, only ever as the side effect of posting a
movement (see `service.py`'s atomic upsert). `quantity_before` is
deliberately not stored — it's always derivable as
`quantity_after - quantity_delta`, so storing it would just be redundant
data that could drift from the two columns it's computed from.

Per docs/adr/0004, `stock_transactions` ships as a plain (non-partitioned)
table this sprint, and there is no separate `stock_adjustments` table —
an adjustment is just another `movement_type` on this same ledger, using
the `reason`/`note` columns every other movement type also has.
"""

import uuid
from enum import StrEnum

from sqlalchemy import Enum, ForeignKey, Index, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.common.base_model import (
    AuditMixin,
    Base,
    CompanyScopedMixin,
    ConcurrencyMixin,
    IdMixin,
    SyncMixin,
    TimestampMixin,
)


class MovementType(StrEnum):
    STOCK_IN = "stock_in"
    STOCK_OUT = "stock_out"
    TRANSFER_OUT = "transfer_out"
    TRANSFER_IN = "transfer_in"
    ADJUSTMENT = "adjustment"


class StockLevel(
    Base, IdMixin, CompanyScopedMixin, TimestampMixin, ConcurrencyMixin, SyncMixin, AuditMixin
):
    """Current balance for one variant in one warehouse. Mutated only via
    the atomic `ON CONFLICT ... DO UPDATE` upsert in `repository.py` —
    never a plain `UPDATE`, so concurrent movements on the same row can't
    lose an update. Deliberately no `CHECK (quantity >= 0)`:
    `allow_negative_stock` is a legitimate per-product policy enforced at
    the service layer, not a DB-level invariant.
    """

    __tablename__ = "stock_levels"
    __table_args__ = (
        UniqueConstraint(
            "company_id",
            "warehouse_id",
            "product_variant_id",
            name="uq_stock_levels_company_warehouse_variant",
        ),
    )

    warehouse_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("warehouses.id"), nullable=False, index=True
    )
    product_variant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("product_variants.id"), nullable=False, index=True
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)


class StockTransfer(Base, IdMixin, CompanyScopedMixin, TimestampMixin, AuditMixin):
    """Header row grouping one transfer's two ledger legs. No status/
    state machine — transfers are synchronous (source decremented,
    destination incremented, both ledger rows written, all in one DB
    transaction) — see docs/adr/0004 for why an in-transit workflow is
    out of scope this sprint.
    """

    __tablename__ = "stock_transfers"

    from_warehouse_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("warehouses.id"), nullable=False, index=True
    )
    to_warehouse_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("warehouses.id"), nullable=False, index=True
    )
    product_variant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("product_variants.id"), nullable=False, index=True
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)


class StockTransaction(Base, IdMixin, CompanyScopedMixin, TimestampMixin, AuditMixin):
    """Immutable, append-only movement ledger — never updated or
    deleted, so it carries no `ConcurrencyMixin`/`SoftDeleteMixin`,
    matching the `AuditLog` precedent. `branch_id` is denormalized from
    the warehouse (a warehouse's branch is not currently mutable through
    any API) purely so branch-level reporting doesn't need a join.
    """

    __tablename__ = "stock_transactions"
    __table_args__ = (
        Index("ix_stock_transactions_company_created_at", "company_id", "created_at"),
        Index(
            "ix_stock_transactions_company_variant_created_at",
            "company_id",
            "product_variant_id",
            "created_at",
        ),
    )

    branch_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("branches.id"), nullable=False, index=True
    )
    warehouse_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("warehouses.id"), nullable=False, index=True
    )
    product_variant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("product_variants.id"), nullable=False, index=True
    )
    movement_type: Mapped[MovementType] = mapped_column(
        Enum(
            MovementType,
            native_enum=False,
            length=20,
            validate_strings=True,
            values_callable=lambda enum_cls: [member.value for member in enum_cls],
        ),
        nullable=False,
    )
    quantity_delta: Mapped[int] = mapped_column(Integer, nullable=False)
    quantity_after: Mapped[int] = mapped_column(Integer, nullable=False)
    reason: Mapped[str | None] = mapped_column(String(100), nullable=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    transfer_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("stock_transfers.id"), nullable=True, index=True
    )
