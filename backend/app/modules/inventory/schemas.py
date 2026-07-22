"""Pydantic request/response schemas for Stock In/Out/Adjustment/Transfer
and the stock/transaction-history read models.
"""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.common.schemas import ORMSchema
from app.modules.inventory.models import MovementType


class StockInRequest(BaseModel):
    warehouse_id: UUID
    product_variant_id: UUID
    quantity: int = Field(gt=0)
    reason: str | None = Field(default=None, max_length=100)
    note: str | None = None


class StockOutRequest(BaseModel):
    warehouse_id: UUID
    product_variant_id: UUID
    quantity: int = Field(gt=0)
    reason: str | None = Field(default=None, max_length=100)
    note: str | None = None


class AdjustmentRequest(BaseModel):
    warehouse_id: UUID
    product_variant_id: UUID
    counted_quantity: int = Field(ge=0)
    reason: str = Field(min_length=1, max_length=100)
    note: str | None = None


class TransferRequest(BaseModel):
    from_warehouse_id: UUID
    to_warehouse_id: UUID
    product_variant_id: UUID
    quantity: int = Field(gt=0)
    note: str | None = None


class StockLevelRead(BaseModel):
    """Assembled from `InventoryService.StockLevelSummary`, not a direct
    ORM row — see that dataclass's docstring for why."""

    warehouse_id: UUID | None
    product_id: UUID
    product_variant_id: UUID
    sku: str
    product_name: str
    variant_name: str | None
    low_stock_threshold: int | None
    quantity: int
    is_low_stock: bool


class StockTransactionRead(ORMSchema):
    id: UUID
    company_id: UUID
    branch_id: UUID
    warehouse_id: UUID
    product_variant_id: UUID
    movement_type: MovementType
    quantity_delta: int
    quantity_after: int
    reason: str | None
    note: str | None
    transfer_id: UUID | None
    created_at: datetime


class StockTransferRead(ORMSchema):
    id: UUID
    company_id: UUID
    from_warehouse_id: UUID
    to_warehouse_id: UUID
    product_variant_id: UUID
    quantity: int
    note: str | None
    created_at: datetime
