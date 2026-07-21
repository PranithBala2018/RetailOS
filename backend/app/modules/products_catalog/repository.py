"""Data access for Category, Brand, Unit, Product, ProductVariant,
ProductBarcode, ProductImage. Every method takes an explicit
`company_id` and filters by it — application-layer tenant isolation,
same as every Sprint 2 repository (docs/adr/0003).
"""

from uuid import UUID

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.products_catalog.models import (
    Brand,
    Category,
    Product,
    ProductBarcode,
    ProductImage,
    ProductVariant,
    Unit,
)


class CategoryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, company_id: UUID, category_id: UUID) -> Category | None:
        stmt = select(Category).where(
            Category.id == category_id,
            Category.company_id == company_id,
            Category.deleted_at.is_(None),
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_for_company(self, company_id: UUID) -> list[Category]:
        stmt = (
            select(Category)
            .where(Category.company_id == company_id, Category.deleted_at.is_(None))
            .order_by(Category.display_order, Category.name)
        )
        return list((await self._session.execute(stmt)).scalars().all())

    async def get_by_name(self, company_id: UUID, name: str) -> Category | None:
        stmt = select(Category).where(
            Category.company_id == company_id, Category.name == name, Category.deleted_at.is_(None)
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def create(self, category: Category) -> Category:
        self._session.add(category)
        await self._session.flush()
        return category


class BrandRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, company_id: UUID, brand_id: UUID) -> Brand | None:
        stmt = select(Brand).where(
            Brand.id == brand_id, Brand.company_id == company_id, Brand.deleted_at.is_(None)
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_for_company(self, company_id: UUID) -> list[Brand]:
        stmt = (
            select(Brand)
            .where(Brand.company_id == company_id, Brand.deleted_at.is_(None))
            .order_by(Brand.name)
        )
        return list((await self._session.execute(stmt)).scalars().all())

    async def get_by_name(self, company_id: UUID, name: str) -> Brand | None:
        stmt = select(Brand).where(
            Brand.company_id == company_id, Brand.name == name, Brand.deleted_at.is_(None)
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def create(self, brand: Brand) -> Brand:
        self._session.add(brand)
        await self._session.flush()
        return brand


class UnitRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, unit_id: UUID) -> Unit | None:
        stmt = select(Unit).where(Unit.id == unit_id, Unit.deleted_at.is_(None))
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_available_for_company(self, company_id: UUID) -> list[Unit]:
        """System defaults (company_id IS NULL) plus this company's own
        custom units — same pattern as Role in Sprint 2."""
        stmt = (
            select(Unit)
            .where(
                or_(Unit.company_id.is_(None), Unit.company_id == company_id),
                Unit.deleted_at.is_(None),
            )
            .order_by(Unit.name)
        )
        return list((await self._session.execute(stmt)).scalars().all())

    async def create(self, unit: Unit) -> Unit:
        self._session.add(unit)
        await self._session.flush()
        return unit


class ProductRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, company_id: UUID, product_id: UUID) -> Product | None:
        stmt = select(Product).where(
            Product.id == product_id, Product.company_id == company_id, Product.deleted_at.is_(None)
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def get_by_sku(self, company_id: UUID, sku: str) -> Product | None:
        stmt = select(Product).where(
            Product.company_id == company_id, Product.sku == sku, Product.deleted_at.is_(None)
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_for_company(
        self, company_id: UUID, *, search: str | None = None, category_id: UUID | None = None
    ) -> list[Product]:
        stmt = select(Product).where(Product.company_id == company_id, Product.deleted_at.is_(None))
        if search:
            stmt = stmt.where(
                or_(Product.name.ilike(f"%{search}%"), Product.sku.ilike(f"%{search}%"))
            )
        if category_id is not None:
            stmt = stmt.where(Product.category_id == category_id)
        stmt = stmt.order_by(Product.name)
        return list((await self._session.execute(stmt)).scalars().all())

    async def create(self, product: Product) -> Product:
        self._session.add(product)
        await self._session.flush()
        return product


class ProductVariantRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, company_id: UUID, variant_id: UUID) -> ProductVariant | None:
        stmt = select(ProductVariant).where(
            ProductVariant.id == variant_id,
            ProductVariant.company_id == company_id,
            ProductVariant.deleted_at.is_(None),
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def get_by_sku(self, company_id: UUID, sku: str) -> ProductVariant | None:
        stmt = select(ProductVariant).where(
            ProductVariant.company_id == company_id,
            ProductVariant.sku == sku,
            ProductVariant.deleted_at.is_(None),
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_for_product(self, company_id: UUID, product_id: UUID) -> list[ProductVariant]:
        stmt = (
            select(ProductVariant)
            .where(
                ProductVariant.company_id == company_id,
                ProductVariant.product_id == product_id,
                ProductVariant.deleted_at.is_(None),
            )
            .order_by(ProductVariant.sku)
        )
        return list((await self._session.execute(stmt)).scalars().all())

    async def create(self, variant: ProductVariant) -> ProductVariant:
        self._session.add(variant)
        await self._session.flush()
        return variant


class ProductBarcodeRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_barcode(self, company_id: UUID, barcode: str) -> ProductBarcode | None:
        stmt = select(ProductBarcode).where(
            ProductBarcode.company_id == company_id,
            ProductBarcode.barcode == barcode,
            ProductBarcode.deleted_at.is_(None),
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def list_for_variant(self, company_id: UUID, variant_id: UUID) -> list[ProductBarcode]:
        stmt = select(ProductBarcode).where(
            ProductBarcode.company_id == company_id,
            ProductBarcode.product_variant_id == variant_id,
            ProductBarcode.deleted_at.is_(None),
        )
        return list((await self._session.execute(stmt)).scalars().all())

    async def create(self, barcode: ProductBarcode) -> ProductBarcode:
        self._session.add(barcode)
        await self._session.flush()
        return barcode


class ProductImageRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_for_product(self, company_id: UUID, product_id: UUID) -> list[ProductImage]:
        stmt = (
            select(ProductImage)
            .where(ProductImage.company_id == company_id, ProductImage.product_id == product_id)
            .order_by(ProductImage.display_order)
        )
        return list((await self._session.execute(stmt)).scalars().all())

    async def create(self, image: ProductImage) -> ProductImage:
        self._session.add(image)
        await self._session.flush()
        return image
