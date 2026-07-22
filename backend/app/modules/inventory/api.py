"""Stock In/Out/Transfer/Adjustment, current-stock/low-stock queries, and
the transaction ledger — every route scoped to `current_user.company_id`
and gated behind the matching `inventory.*` permission code.
"""

from datetime import datetime
from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.pagination import Page
from app.common.response import success_envelope
from app.core.db import get_db_session
from app.modules.auth.dependencies import require_permission
from app.modules.inventory.models import MovementType
from app.modules.inventory.schemas import (
    AdjustmentRequest,
    StockInRequest,
    StockLevelRead,
    StockOutRequest,
    StockTransactionRead,
    StockTransferRead,
    TransferRequest,
)
from app.modules.inventory.service import InventoryService, StockLevelSummary
from app.modules.users_roles_permissions.models import User

router = APIRouter(tags=["inventory"])


def _stock_level_read(summary: StockLevelSummary) -> dict[str, Any]:
    return StockLevelRead(
        warehouse_id=summary.warehouse_id,
        product_id=summary.product.id,
        product_variant_id=summary.variant.id,
        sku=summary.variant.sku,
        product_name=summary.product.name,
        variant_name=summary.variant.variant_name,
        low_stock_threshold=summary.product.low_stock_threshold,
        quantity=summary.quantity,
        is_low_stock=summary.is_low_stock,
    ).model_dump(mode="json")


@router.get("/inventory/stock")
async def list_stock(
    warehouse_id: UUID | None = Query(default=None),
    search: str | None = Query(default=None),
    category_id: UUID | None = Query(default=None),
    low_stock_only: bool = Query(default=False),
    current_user: User = Depends(require_permission("inventory.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    summaries = await InventoryService(session).list_stock(
        current_user.company_id,
        warehouse_id=warehouse_id,
        search=search,
        category_id=category_id,
        low_stock_only=low_stock_only,
    )
    return success_envelope(data=[_stock_level_read(s) for s in summaries])


@router.get("/inventory/stock/{product_variant_id}")
async def get_stock_level(
    product_variant_id: UUID,
    warehouse_id: UUID | None = Query(default=None),
    current_user: User = Depends(require_permission("inventory.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    summary = await InventoryService(session).get_stock_level(
        current_user.company_id, product_variant_id, warehouse_id=warehouse_id
    )
    return success_envelope(data=_stock_level_read(summary))


@router.get("/inventory/low-stock")
async def list_low_stock(
    warehouse_id: UUID | None = Query(default=None),
    current_user: User = Depends(require_permission("inventory.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    summaries = await InventoryService(session).list_low_stock(
        current_user.company_id, warehouse_id=warehouse_id
    )
    return success_envelope(data=[_stock_level_read(s) for s in summaries])


@router.post("/inventory/stock-in")
async def stock_in(
    data: StockInRequest,
    current_user: User = Depends(require_permission("inventory.stock_in")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    transaction = await InventoryService(session).stock_in(
        current_user.company_id,
        current_user.id,
        warehouse_id=data.warehouse_id,
        product_variant_id=data.product_variant_id,
        quantity=data.quantity,
        reason=data.reason,
        note=data.note,
    )
    return success_envelope(
        data=StockTransactionRead.model_validate(transaction).model_dump(mode="json"),
        message="Stock in recorded",
    )


@router.post("/inventory/stock-out")
async def stock_out(
    data: StockOutRequest,
    current_user: User = Depends(require_permission("inventory.stock_out")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    transaction = await InventoryService(session).stock_out(
        current_user.company_id,
        current_user.id,
        warehouse_id=data.warehouse_id,
        product_variant_id=data.product_variant_id,
        quantity=data.quantity,
        reason=data.reason,
        note=data.note,
    )
    return success_envelope(
        data=StockTransactionRead.model_validate(transaction).model_dump(mode="json"),
        message="Stock out recorded",
    )


@router.post("/inventory/adjustments")
async def adjust_stock(
    data: AdjustmentRequest,
    current_user: User = Depends(require_permission("inventory.adjust")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    transaction = await InventoryService(session).adjust(
        current_user.company_id,
        current_user.id,
        warehouse_id=data.warehouse_id,
        product_variant_id=data.product_variant_id,
        counted_quantity=data.counted_quantity,
        reason=data.reason,
        note=data.note,
    )
    return success_envelope(
        data=StockTransactionRead.model_validate(transaction).model_dump(mode="json"),
        message="Adjustment recorded",
    )


@router.post("/inventory/transfers")
async def transfer_stock(
    data: TransferRequest,
    current_user: User = Depends(require_permission("inventory.transfer")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    transfer = await InventoryService(session).transfer(
        current_user.company_id,
        current_user.id,
        from_warehouse_id=data.from_warehouse_id,
        to_warehouse_id=data.to_warehouse_id,
        product_variant_id=data.product_variant_id,
        quantity=data.quantity,
        note=data.note,
    )
    return success_envelope(
        data=StockTransferRead.model_validate(transfer).model_dump(mode="json"),
        message="Transfer recorded",
    )


@router.get("/inventory/transactions")
async def list_transactions(
    warehouse_id: UUID | None = Query(default=None),
    product_variant_id: UUID | None = Query(default=None),
    movement_type: MovementType | None = Query(default=None),
    date_from: datetime | None = Query(default=None),
    date_to: datetime | None = Query(default=None),
    cursor: str | None = Query(default=None),
    limit: int = Query(default=25, ge=1, le=100),
    current_user: User = Depends(require_permission("inventory.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    raw_page = await InventoryService(session).list_transactions(
        current_user.company_id,
        warehouse_id=warehouse_id,
        product_variant_id=product_variant_id,
        movement_type=movement_type,
        date_from=date_from,
        date_to=date_to,
        cursor=cursor,
        limit=limit,
    )
    page: Page[StockTransactionRead] = Page(
        items=[StockTransactionRead.model_validate(t) for t in raw_page.items],
        next_cursor=raw_page.next_cursor,
        has_more=raw_page.has_more,
    )
    return success_envelope(data=page.model_dump(mode="json"))
