"""Data access for StockLevel, StockTransaction, StockTransfer.

`StockLevelRepository.upsert_delta` is the one method in this whole
codebase that mutates a counter via a single atomic SQL statement rather
than a Python read-modify-write — see its docstring and
`docs/adr/0004-inventory-sprint4-scope-deviations.md` for why that's
required here specifically (concurrent stock movements on the same
variant/warehouse must never lose an update).
"""

import base64
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from sqlalchemy import literal, select, tuple_, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.inventory.models import MovementType, StockLevel, StockTransaction, StockTransfer


@dataclass
class RawTransactionPage:
    """Plain (non-Pydantic) pagination container for ORM rows. The
    shared `app.common.pagination.Page[T]` is a Pydantic generic model —
    parameterizing it with a SQLAlchemy ORM class (`Page[StockTransaction]`)
    fails at import time (`PydanticSchemaGenerationError`), since Pydantic
    eagerly builds a schema for whatever `T` is the moment the generic is
    referenced. `Page[StockTransactionRead]`, parameterized with the
    Pydantic *read schema* after converting these rows, is what the API
    layer actually returns — this type only carries ORM rows between the
    repository and service layers.
    """

    items: list[StockTransaction]
    next_cursor: str | None
    has_more: bool


def encode_cursor(created_at: datetime, transaction_id: UUID) -> str:
    raw = f"{created_at.isoformat()}|{transaction_id}"
    return base64.urlsafe_b64encode(raw.encode()).decode()


def decode_cursor(cursor: str) -> tuple[datetime, UUID]:
    raw = base64.urlsafe_b64decode(cursor.encode()).decode()
    created_at_raw, id_raw = raw.split("|", 1)
    return datetime.fromisoformat(created_at_raw), UUID(id_raw)


class StockLevelRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(
        self, company_id: UUID, warehouse_id: UUID, product_variant_id: UUID
    ) -> StockLevel | None:
        stmt = select(StockLevel).where(
            StockLevel.company_id == company_id,
            StockLevel.warehouse_id == warehouse_id,
            StockLevel.product_variant_id == product_variant_id,
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_for_variant_ids(
        self, company_id: UUID, variant_ids: Sequence[UUID], *, warehouse_id: UUID | None = None
    ) -> list[StockLevel]:
        if not variant_ids:
            return []
        stmt = select(StockLevel).where(
            StockLevel.company_id == company_id, StockLevel.product_variant_id.in_(variant_ids)
        )
        if warehouse_id is not None:
            stmt = stmt.where(StockLevel.warehouse_id == warehouse_id)
        return list((await self._session.execute(stmt)).scalars().all())

    async def upsert_delta(
        self,
        *,
        id_: UUID,
        company_id: UUID,
        warehouse_id: UUID,
        product_variant_id: UUID,
        delta: int,
    ) -> int:
        """Atomically applies `delta` to the current quantity for this
        `(company_id, warehouse_id, product_variant_id)`, creating the row
        (starting from 0) if it doesn't exist yet. A single
        `INSERT ... ON CONFLICT DO UPDATE` rather than a `SELECT` then
        `UPDATE`: Postgres takes the row lock via the unique index on the
        `INSERT`, so a second concurrent call on the same key blocks until
        the first commits, then evaluates `quantity + delta` against the
        *post-commit* value — never a stale read, so this can't lose an
        update or let two concurrent movements over-sell stock. Returns
        the new quantity so the caller can check it against policy
        (`allow_negative_stock`) before the surrounding transaction
        commits — raising there rolls back this upsert too.
        """
        stmt = (
            pg_insert(StockLevel)
            .values(
                id=id_,
                company_id=company_id,
                warehouse_id=warehouse_id,
                product_variant_id=product_variant_id,
                quantity=delta,
                version=1,
            )
            .on_conflict_do_update(
                index_elements=[
                    StockLevel.company_id,
                    StockLevel.warehouse_id,
                    StockLevel.product_variant_id,
                ],
                set_={
                    "quantity": StockLevel.quantity + delta,
                    "version": StockLevel.version + 1,
                },
            )
            .returning(StockLevel.quantity)
        )
        result = await self._session.execute(stmt)
        return result.scalar_one()

    async def set_absolute(
        self,
        *,
        id_: UUID,
        company_id: UUID,
        warehouse_id: UUID,
        product_variant_id: UUID,
        new_quantity: int,
    ) -> int:
        """Row-locks the stock_levels row (creating it with quantity=0
        first if it doesn't exist yet) and sets its quantity to an
        absolute value. Used only by adjustments, where the caller
        supplies a physically recounted total rather than a delta — a
        different operation from `upsert_delta`'s additive semantics, so
        it needs an explicit `SELECT ... FOR UPDATE` to read "the value
        immediately before this set" with no race window, rather than
        computing a delta from a value read before the lock was taken.
        Returns the quantity that was current under that lock, so the
        caller can compute an accurate ledger delta.

        The `INSERT ... ON CONFLICT DO NOTHING` and the subsequent
        `SELECT ... FOR UPDATE` are still race-free against a concurrent
        `upsert_delta` call on the same key: both take the same row-level
        lock (via the unique index / `FOR UPDATE`), so whichever
        statement — from either method — arrives first blocks the other
        until it commits.
        """
        await self._session.execute(
            pg_insert(StockLevel)
            .values(
                id=id_,
                company_id=company_id,
                warehouse_id=warehouse_id,
                product_variant_id=product_variant_id,
                quantity=0,
                version=1,
            )
            .on_conflict_do_nothing(
                index_elements=[
                    StockLevel.company_id,
                    StockLevel.warehouse_id,
                    StockLevel.product_variant_id,
                ]
            )
        )
        previous_quantity = (
            await self._session.execute(
                select(StockLevel.quantity)
                .where(
                    StockLevel.company_id == company_id,
                    StockLevel.warehouse_id == warehouse_id,
                    StockLevel.product_variant_id == product_variant_id,
                )
                .with_for_update()
            )
        ).scalar_one()
        await self._session.execute(
            update(StockLevel)
            .where(
                StockLevel.company_id == company_id,
                StockLevel.warehouse_id == warehouse_id,
                StockLevel.product_variant_id == product_variant_id,
            )
            .values(quantity=new_quantity, version=StockLevel.version + 1)
        )
        return previous_quantity


class StockTransferRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(self, transfer: StockTransfer) -> StockTransfer:
        self._session.add(transfer)
        await self._session.flush()
        return transfer


class StockTransactionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(self, transaction: StockTransaction) -> StockTransaction:
        self._session.add(transaction)
        await self._session.flush()
        return transaction

    async def list_page(
        self,
        company_id: UUID,
        *,
        warehouse_id: UUID | None = None,
        product_variant_id: UUID | None = None,
        movement_type: MovementType | None = None,
        date_from: datetime | None = None,
        date_to: datetime | None = None,
        cursor: str | None = None,
        limit: int = 25,
    ) -> RawTransactionPage:
        stmt = select(StockTransaction).where(StockTransaction.company_id == company_id)
        if warehouse_id is not None:
            stmt = stmt.where(StockTransaction.warehouse_id == warehouse_id)
        if product_variant_id is not None:
            stmt = stmt.where(StockTransaction.product_variant_id == product_variant_id)
        if movement_type is not None:
            stmt = stmt.where(StockTransaction.movement_type == movement_type)
        if date_from is not None:
            stmt = stmt.where(StockTransaction.created_at >= date_from)
        if date_to is not None:
            stmt = stmt.where(StockTransaction.created_at <= date_to)
        if cursor is not None:
            cursor_created_at, cursor_id = decode_cursor(cursor)
            stmt = stmt.where(
                tuple_(StockTransaction.created_at, StockTransaction.id)
                < tuple_(literal(cursor_created_at), literal(cursor_id))
            )

        stmt = stmt.order_by(StockTransaction.created_at.desc(), StockTransaction.id.desc()).limit(
            limit + 1
        )
        rows = list((await self._session.execute(stmt)).scalars().all())

        has_more = len(rows) > limit
        page_rows = rows[:limit]
        next_cursor = (
            encode_cursor(page_rows[-1].created_at, page_rows[-1].id)
            if has_more and page_rows
            else None
        )
        return RawTransactionPage(items=page_rows, next_cursor=next_cursor, has_more=has_more)
