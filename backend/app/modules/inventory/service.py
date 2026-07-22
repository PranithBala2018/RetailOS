"""Business logic for Stock In, Stock Out, Transfer, Adjustment, and
stock/low-stock queries.

Cross-module reads reach into `products_catalog` (for `track_inventory`/
`allow_negative_stock`/`low_stock_threshold` policy, which lives on
`Product`, not `ProductVariant`) and `company` (for warehouse existence)
only through their service layers — `ProductService`, `ProductVariantService`,
`WarehouseService` — never their repositories/models directly, per
SPRINT0.md §1.2's cross-module rule.
"""

from dataclasses import dataclass
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NotFoundException, ValidationException
from app.modules.audit.service import AuditService
from app.modules.company.models import Warehouse
from app.modules.company.repository import WarehouseRepository
from app.modules.inventory.models import MovementType, StockTransaction, StockTransfer
from app.modules.inventory.repository import (
    RawTransactionPage,
    StockLevelRepository,
    StockTransactionRepository,
    StockTransferRepository,
)
from app.modules.products_catalog.models import Product, ProductVariant
from app.modules.products_catalog.service import ProductService, ProductVariantService


@dataclass
class StockLevelSummary:
    """A variant's balance, combined with just enough product/variant
    context for the stock list screen — assembled here because it
    spans two modules' data and neither module's own `Read` schema
    covers both halves."""

    warehouse_id: UUID | None
    product: Product
    variant: ProductVariant
    quantity: int

    @property
    def is_low_stock(self) -> bool:
        threshold = self.product.low_stock_threshold
        return self.product.track_inventory and threshold is not None and self.quantity <= threshold


class InventoryService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._stock_level_repo = StockLevelRepository(session)
        self._transaction_repo = StockTransactionRepository(session)
        self._transfer_repo = StockTransferRepository(session)
        self._warehouse_repo = WarehouseRepository(session)
        self._product_service = ProductService(session)
        self._variant_service = ProductVariantService(session)
        self._audit = AuditService(session)

    async def _get_warehouse(self, company_id: UUID, warehouse_id: UUID) -> Warehouse:
        warehouse = await self._warehouse_repo.get_by_id(company_id, warehouse_id)
        if warehouse is None:
            raise NotFoundException("Warehouse not found")
        return warehouse

    async def _get_variant_and_product(
        self, company_id: UUID, product_variant_id: UUID
    ) -> tuple[ProductVariant, Product]:
        variant = await self._variant_service.get(company_id, product_variant_id)
        product = await self._product_service.get(company_id, variant.product_id)
        return variant, product

    def _check_policy(self, product: Product, resulting_quantity: int) -> None:
        if not product.track_inventory:
            raise ValidationException(
                f"'{product.name}' does not track inventory", field="product_variant_id"
            )
        if resulting_quantity < 0 and not product.allow_negative_stock:
            raise ValidationException(
                f"Insufficient stock for '{product.name}' — this movement would take the "
                "balance negative, and negative stock isn't allowed for this product.",
                field="quantity",
            )

    async def _record_delta_movement(
        self,
        *,
        company_id: UUID,
        warehouse: Warehouse,
        variant: ProductVariant,
        product: Product,
        movement_type: MovementType,
        delta: int,
        reason: str | None,
        note: str | None,
        user_id: UUID | None,
        transfer_id: UUID | None = None,
    ) -> StockTransaction:
        new_quantity = await self._stock_level_repo.upsert_delta(
            id_=uuid4(),
            company_id=company_id,
            warehouse_id=warehouse.id,
            product_variant_id=variant.id,
            delta=delta,
        )
        self._check_policy(product, new_quantity)
        return await self._write_ledger_row(
            company_id=company_id,
            warehouse=warehouse,
            variant=variant,
            movement_type=movement_type,
            delta=delta,
            new_quantity=new_quantity,
            reason=reason,
            note=note,
            user_id=user_id,
            transfer_id=transfer_id,
        )

    async def _write_ledger_row(
        self,
        *,
        company_id: UUID,
        warehouse: Warehouse,
        variant: ProductVariant,
        movement_type: MovementType,
        delta: int,
        new_quantity: int,
        reason: str | None,
        note: str | None,
        user_id: UUID | None,
        transfer_id: UUID | None,
    ) -> StockTransaction:
        transaction = StockTransaction(
            id=uuid4(),
            company_id=company_id,
            branch_id=warehouse.branch_id,
            warehouse_id=warehouse.id,
            product_variant_id=variant.id,
            movement_type=movement_type,
            quantity_delta=delta,
            quantity_after=new_quantity,
            reason=reason,
            note=note,
            transfer_id=transfer_id,
        )
        await self._transaction_repo.create(transaction)
        await self._audit.log(
            f"inventory.{movement_type.value}",
            company_id=company_id,
            user_id=user_id,
            entity_table="stock_transactions",
            entity_id=transaction.id,
            after_data={
                "warehouse_id": str(warehouse.id),
                "product_variant_id": str(variant.id),
                "quantity_delta": delta,
                "quantity_after": new_quantity,
            },
        )
        return transaction

    async def stock_in(
        self,
        company_id: UUID,
        user_id: UUID,
        *,
        warehouse_id: UUID,
        product_variant_id: UUID,
        quantity: int,
        reason: str | None = None,
        note: str | None = None,
    ) -> StockTransaction:
        if quantity <= 0:
            raise ValidationException("Quantity must be positive", field="quantity")
        warehouse = await self._get_warehouse(company_id, warehouse_id)
        variant, product = await self._get_variant_and_product(company_id, product_variant_id)
        transaction = await self._record_delta_movement(
            company_id=company_id,
            warehouse=warehouse,
            variant=variant,
            product=product,
            movement_type=MovementType.STOCK_IN,
            delta=quantity,
            reason=reason,
            note=note,
            user_id=user_id,
        )
        await self._session.flush()
        return transaction

    async def stock_out(
        self,
        company_id: UUID,
        user_id: UUID,
        *,
        warehouse_id: UUID,
        product_variant_id: UUID,
        quantity: int,
        reason: str | None = None,
        note: str | None = None,
    ) -> StockTransaction:
        if quantity <= 0:
            raise ValidationException("Quantity must be positive", field="quantity")
        warehouse = await self._get_warehouse(company_id, warehouse_id)
        variant, product = await self._get_variant_and_product(company_id, product_variant_id)
        transaction = await self._record_delta_movement(
            company_id=company_id,
            warehouse=warehouse,
            variant=variant,
            product=product,
            movement_type=MovementType.STOCK_OUT,
            delta=-quantity,
            reason=reason,
            note=note,
            user_id=user_id,
        )
        await self._session.flush()
        return transaction

    async def adjust(
        self,
        company_id: UUID,
        user_id: UUID,
        *,
        warehouse_id: UUID,
        product_variant_id: UUID,
        counted_quantity: int,
        reason: str,
        note: str | None = None,
    ) -> StockTransaction:
        """Takes the physically recounted total, not a delta — the
        delta is computed server-side from the value read under the same
        row lock that sets the new total, so there's no race window
        between "read the current count" and "apply the correction".
        """
        if counted_quantity < 0:
            raise ValidationException(
                "Counted quantity cannot be negative", field="counted_quantity"
            )
        warehouse = await self._get_warehouse(company_id, warehouse_id)
        variant, product = await self._get_variant_and_product(company_id, product_variant_id)
        if not product.track_inventory:
            raise ValidationException(
                f"'{product.name}' does not track inventory", field="product_variant_id"
            )

        previous_quantity = await self._stock_level_repo.set_absolute(
            id_=uuid4(),
            company_id=company_id,
            warehouse_id=warehouse_id,
            product_variant_id=product_variant_id,
            new_quantity=counted_quantity,
        )
        delta = counted_quantity - previous_quantity
        transaction = await self._write_ledger_row(
            company_id=company_id,
            warehouse=warehouse,
            variant=variant,
            movement_type=MovementType.ADJUSTMENT,
            delta=delta,
            new_quantity=counted_quantity,
            reason=reason,
            note=note,
            user_id=user_id,
            transfer_id=None,
        )
        await self._session.flush()
        return transaction

    async def transfer(
        self,
        company_id: UUID,
        user_id: UUID,
        *,
        from_warehouse_id: UUID,
        to_warehouse_id: UUID,
        product_variant_id: UUID,
        quantity: int,
        note: str | None = None,
    ) -> StockTransfer:
        if quantity <= 0:
            raise ValidationException("Quantity must be positive", field="quantity")
        if from_warehouse_id == to_warehouse_id:
            raise ValidationException(
                "Source and destination warehouse must be different", field="to_warehouse_id"
            )

        from_warehouse = await self._get_warehouse(company_id, from_warehouse_id)
        to_warehouse = await self._get_warehouse(company_id, to_warehouse_id)
        variant, product = await self._get_variant_and_product(company_id, product_variant_id)

        transfer = StockTransfer(
            id=uuid4(),
            company_id=company_id,
            from_warehouse_id=from_warehouse_id,
            to_warehouse_id=to_warehouse_id,
            product_variant_id=product_variant_id,
            quantity=quantity,
            note=note,
        )
        await self._transfer_repo.create(transfer)

        # Canonical lock ordering: always touch the lexicographically
        # smaller warehouse_id first, regardless of transfer direction,
        # so two concurrent transfers between the same warehouse pair in
        # opposite directions can't deadlock on each other's second lock.
        first, second = sorted(
            [
                (from_warehouse, -quantity, MovementType.TRANSFER_OUT),
                (to_warehouse, quantity, MovementType.TRANSFER_IN),
            ],
            key=lambda leg: str(leg[0].id),
        )
        for warehouse, delta, movement_type in (first, second):
            await self._record_delta_movement(
                company_id=company_id,
                warehouse=warehouse,
                variant=variant,
                product=product,
                movement_type=movement_type,
                delta=delta,
                reason=None,
                note=note,
                user_id=user_id,
                transfer_id=transfer.id,
            )

        await self._session.flush()
        return transfer

    async def get_stock_level(
        self, company_id: UUID, product_variant_id: UUID, *, warehouse_id: UUID | None = None
    ) -> StockLevelSummary:
        variant, product = await self._get_variant_and_product(company_id, product_variant_id)
        levels = await self._stock_level_repo.list_for_variant_ids(
            company_id, [product_variant_id], warehouse_id=warehouse_id
        )
        quantity = sum(level.quantity for level in levels)
        return StockLevelSummary(
            warehouse_id=warehouse_id, product=product, variant=variant, quantity=quantity
        )

    async def list_stock(
        self,
        company_id: UUID,
        *,
        warehouse_id: UUID | None = None,
        search: str | None = None,
        category_id: UUID | None = None,
        low_stock_only: bool = False,
    ) -> list[StockLevelSummary]:
        products = await self._product_service.list_for_company(
            company_id, search=search, category_id=category_id
        )
        variants_by_id: dict[UUID, ProductVariant] = {}
        products_by_variant_id: dict[UUID, Product] = {}
        for product in products:
            for variant in await self._variant_service.list_for_product(company_id, product.id):
                variants_by_id[variant.id] = variant
                products_by_variant_id[variant.id] = product

        levels = await self._stock_level_repo.list_for_variant_ids(
            company_id, list(variants_by_id.keys()), warehouse_id=warehouse_id
        )
        quantity_by_variant_id: dict[UUID, int] = {}
        for level in levels:
            quantity_by_variant_id[level.product_variant_id] = (
                quantity_by_variant_id.get(level.product_variant_id, 0) + level.quantity
            )

        summaries = [
            StockLevelSummary(
                warehouse_id=warehouse_id,
                product=products_by_variant_id[variant_id],
                variant=variant,
                quantity=quantity_by_variant_id.get(variant_id, 0),
            )
            for variant_id, variant in variants_by_id.items()
        ]
        if low_stock_only:
            summaries = [s for s in summaries if s.is_low_stock]
        return summaries

    async def list_low_stock(
        self, company_id: UUID, *, warehouse_id: UUID | None = None
    ) -> list[StockLevelSummary]:
        return await self.list_stock(company_id, warehouse_id=warehouse_id, low_stock_only=True)

    async def list_transactions(
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
        return await self._transaction_repo.list_page(
            company_id,
            warehouse_id=warehouse_id,
            product_variant_id=product_variant_id,
            movement_type=movement_type,
            date_from=date_from,
            date_to=date_to,
            cursor=cursor,
            limit=limit,
        )
