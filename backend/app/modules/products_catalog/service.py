"""Business logic for Categories, Brands, Units, Products, Variants,
Barcodes, Images.

The one non-obvious rule enforced here: every product ends up with at
least one `ProductVariant` row (see models.py module docstring). For a
`has_variants=False` product, `ProductService.create` synthesizes exactly
one variant from the top-level pricing fields on `ProductCreate`, reusing
the product's own SKU. For `has_variants=True`, the caller-supplied
`variants` list is authoritative and must be non-empty.
"""

from dataclasses import dataclass
from uuid import UUID, uuid4

from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.db_utils import affected_rows
from app.core.exceptions import (
    AppException,
    ConflictException,
    NotFoundException,
    ValidationException,
)
from app.modules.products_catalog.csv_io import (
    ProductExportRow,
    ProductImportGroup,
    parse_products_csv,
    write_products_csv,
)
from app.modules.products_catalog.models import (
    Brand,
    Category,
    Product,
    ProductBarcode,
    ProductGender,
    ProductImage,
    ProductVariant,
    Unit,
)
from app.modules.products_catalog.repository import (
    BrandRepository,
    CategoryRepository,
    ProductBarcodeRepository,
    ProductImageRepository,
    ProductRepository,
    ProductVariantRepository,
    UnitRepository,
)
from app.modules.products_catalog.schemas import (
    BrandCreate,
    BrandUpdate,
    CategoryCreate,
    CategoryUpdate,
    ProductBarcodeCreate,
    ProductCreate,
    ProductImageCreate,
    ProductUpdate,
    ProductVariantInput,
    ProductVariantUpdate,
    UnitCreate,
)


def _variant_name(size: str | None, color: str | None) -> str | None:
    parts = [p for p in (color, size) if p]
    return " / ".join(parts) if parts else None


class CategoryService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = CategoryRepository(session)

    async def get(self, company_id: UUID, category_id: UUID) -> Category:
        category = await self._repo.get_by_id(company_id, category_id)
        if category is None:
            raise NotFoundException("Category not found")
        return category

    async def list_for_company(self, company_id: UUID) -> list[Category]:
        return await self._repo.list_for_company(company_id)

    async def create(self, company_id: UUID, data: CategoryCreate) -> Category:
        if await self._repo.get_by_name(company_id, data.name) is not None:
            raise ValidationException(f"Category '{data.name}' already exists", field="name")
        if data.parent_category_id is not None:
            await self.get(company_id, data.parent_category_id)

        category = Category(id=uuid4(), company_id=company_id, **data.model_dump())
        return await self._repo.create(category)

    async def update(
        self, company_id: UUID, category_id: UUID, data: CategoryUpdate, expected_version: int
    ) -> Category:
        changes = data.model_dump(exclude_unset=True)
        if not changes:
            return await self.get(company_id, category_id)
        if "parent_category_id" in changes and changes["parent_category_id"] is not None:
            if changes["parent_category_id"] == category_id:
                raise ValidationException(
                    "A category cannot be its own parent", field="parent_category_id"
                )
            await self.get(company_id, changes["parent_category_id"])

        stmt = (
            update(Category)
            .where(
                Category.id == category_id,
                Category.company_id == company_id,
                Category.version == expected_version,
            )
            .values(**changes, version=Category.version + 1)
        )
        result = await self._session.execute(stmt)
        if affected_rows(result) == 0:
            existing = await self._repo.get_by_id(company_id, category_id)
            if existing is None:
                raise NotFoundException("Category not found")
            raise ConflictException(
                "Category was modified by someone else. Reload and try again.", field="version"
            )
        await self._session.flush()
        return await self.get(company_id, category_id)


class BrandService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = BrandRepository(session)

    async def get(self, company_id: UUID, brand_id: UUID) -> Brand:
        brand = await self._repo.get_by_id(company_id, brand_id)
        if brand is None:
            raise NotFoundException("Brand not found")
        return brand

    async def list_for_company(self, company_id: UUID) -> list[Brand]:
        return await self._repo.list_for_company(company_id)

    async def create(self, company_id: UUID, data: BrandCreate) -> Brand:
        if await self._repo.get_by_name(company_id, data.name) is not None:
            raise ValidationException(f"Brand '{data.name}' already exists", field="name")
        brand = Brand(id=uuid4(), company_id=company_id, **data.model_dump())
        return await self._repo.create(brand)

    async def update(
        self, company_id: UUID, brand_id: UUID, data: BrandUpdate, expected_version: int
    ) -> Brand:
        changes = data.model_dump(exclude_unset=True)
        if not changes:
            return await self.get(company_id, brand_id)

        stmt = (
            update(Brand)
            .where(
                Brand.id == brand_id,
                Brand.company_id == company_id,
                Brand.version == expected_version,
            )
            .values(**changes, version=Brand.version + 1)
        )
        result = await self._session.execute(stmt)
        if affected_rows(result) == 0:
            existing = await self._repo.get_by_id(company_id, brand_id)
            if existing is None:
                raise NotFoundException("Brand not found")
            raise ConflictException(
                "Brand was modified by someone else. Reload and try again.", field="version"
            )
        await self._session.flush()
        return await self.get(company_id, brand_id)


class UnitService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = UnitRepository(session)

    async def get(self, unit_id: UUID) -> Unit:
        unit = await self._repo.get_by_id(unit_id)
        if unit is None:
            raise NotFoundException("Unit not found")
        return unit

    async def list_available_for_company(self, company_id: UUID) -> list[Unit]:
        return await self._repo.list_available_for_company(company_id)

    async def create(self, company_id: UUID, data: UnitCreate) -> Unit:
        existing = [
            u
            for u in await self._repo.list_available_for_company(company_id)
            if u.abbreviation == data.abbreviation
        ]
        if existing:
            raise ValidationException(
                f"Unit abbreviation '{data.abbreviation}' is already in use", field="abbreviation"
            )
        unit = Unit(id=uuid4(), company_id=company_id, is_system=False, **data.model_dump())
        return await self._repo.create(unit)

    async def ensure_available_for_company(self, company_id: UUID, unit_id: UUID) -> Unit:
        """A unit is usable by a product if it's a system default or
        belongs to this company — same visibility rule as listing."""
        unit = await self.get(unit_id)
        if unit.company_id is not None and unit.company_id != company_id:
            raise ValidationException("Unit does not belong to this company", field="base_unit_id")
        return unit


class ProductService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = ProductRepository(session)
        self._variant_repo = ProductVariantRepository(session)
        self._category_repo = CategoryRepository(session)
        self._brand_repo = BrandRepository(session)
        self._unit_service = UnitService(session)

    async def get(self, company_id: UUID, product_id: UUID) -> Product:
        product = await self._repo.get_by_id(company_id, product_id)
        if product is None:
            raise NotFoundException("Product not found")
        return product

    async def get_with_variants(
        self, company_id: UUID, product_id: UUID
    ) -> tuple[Product, list[ProductVariant]]:
        product = await self.get(company_id, product_id)
        variants = await self._variant_repo.list_for_product(company_id, product_id)
        return product, variants

    async def list_for_company(
        self, company_id: UUID, *, search: str | None = None, category_id: UUID | None = None
    ) -> list[Product]:
        return await self._repo.list_for_company(company_id, search=search, category_id=category_id)

    async def create(
        self, company_id: UUID, data: ProductCreate
    ) -> tuple[Product, list[ProductVariant]]:
        if await self._repo.get_by_sku(company_id, data.sku) is not None:
            raise ValidationException(f"Product SKU '{data.sku}' already exists", field="sku")
        if data.category_id is not None:
            existing_category = await self._category_repo.get_by_id(company_id, data.category_id)
            if existing_category is None:
                raise NotFoundException("Category not found")
        if data.brand_id is not None:
            existing_brand = await self._brand_repo.get_by_id(company_id, data.brand_id)
            if existing_brand is None:
                raise NotFoundException("Brand not found")
        await self._unit_service.ensure_available_for_company(company_id, data.base_unit_id)

        if data.has_variants and not data.variants:
            raise ValidationException(
                "At least one variant is required when has_variants=True", field="variants"
            )

        product_fields = data.model_dump(
            exclude={"purchase_price", "selling_price", "mrp", "variants"}
        )
        product = Product(id=uuid4(), company_id=company_id, **product_fields)
        await self._repo.create(product)

        variants: list[ProductVariant] = []
        if data.has_variants:
            for variant_input in data.variants:
                variants.append(await self._create_variant(company_id, product.id, variant_input))
        else:
            variants.append(
                await self._create_variant(
                    company_id,
                    product.id,
                    ProductVariantInput(
                        sku=data.sku,
                        purchase_price=data.purchase_price,
                        selling_price=data.selling_price,
                        mrp=data.mrp,
                    ),
                )
            )

        return product, variants

    async def _create_variant(
        self, company_id: UUID, product_id: UUID, data: ProductVariantInput
    ) -> ProductVariant:
        if await self._variant_repo.get_by_sku(company_id, data.sku) is not None:
            raise ValidationException(f"Variant SKU '{data.sku}' already exists", field="sku")
        variant = ProductVariant(
            id=uuid4(),
            company_id=company_id,
            product_id=product_id,
            sku=data.sku,
            size=data.size,
            color=data.color,
            variant_name=_variant_name(data.size, data.color),
            purchase_price=data.purchase_price,
            selling_price=data.selling_price,
            mrp=data.mrp,
        )
        return await self._variant_repo.create(variant)

    async def update(
        self, company_id: UUID, product_id: UUID, data: ProductUpdate, expected_version: int
    ) -> Product:
        changes = data.model_dump(exclude_unset=True)
        if not changes:
            return await self.get(company_id, product_id)
        if changes.get("category_id") is not None and (
            await self._category_repo.get_by_id(company_id, changes["category_id"]) is None
        ):
            raise NotFoundException("Category not found")
        if changes.get("brand_id") is not None and (
            await self._brand_repo.get_by_id(company_id, changes["brand_id"]) is None
        ):
            raise NotFoundException("Brand not found")

        stmt = (
            update(Product)
            .where(
                Product.id == product_id,
                Product.company_id == company_id,
                Product.version == expected_version,
            )
            .values(**changes, version=Product.version + 1)
        )
        result = await self._session.execute(stmt)
        if affected_rows(result) == 0:
            existing = await self._repo.get_by_id(company_id, product_id)
            if existing is None:
                raise NotFoundException("Product not found")
            raise ConflictException(
                "Product was modified by someone else. Reload and try again.", field="version"
            )
        await self._session.flush()
        return await self.get(company_id, product_id)


class ProductVariantService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = ProductVariantRepository(session)
        self._product_repo = ProductRepository(session)

    async def get(self, company_id: UUID, variant_id: UUID) -> ProductVariant:
        variant = await self._repo.get_by_id(company_id, variant_id)
        if variant is None:
            raise NotFoundException("Product variant not found")
        return variant

    async def list_for_product(self, company_id: UUID, product_id: UUID) -> list[ProductVariant]:
        return await self._repo.list_for_product(company_id, product_id)

    async def add_variant(
        self, company_id: UUID, product_id: UUID, data: ProductVariantInput
    ) -> ProductVariant:
        product = await self._product_repo.get_by_id(company_id, product_id)
        if product is None:
            raise NotFoundException("Product not found")
        if await self._repo.get_by_sku(company_id, data.sku) is not None:
            raise ValidationException(f"Variant SKU '{data.sku}' already exists", field="sku")

        variant = ProductVariant(
            id=uuid4(),
            company_id=company_id,
            product_id=product_id,
            sku=data.sku,
            size=data.size,
            color=data.color,
            variant_name=_variant_name(data.size, data.color),
            purchase_price=data.purchase_price,
            selling_price=data.selling_price,
            mrp=data.mrp,
        )
        await self._repo.create(variant)

        if not product.has_variants:
            product.has_variants = True
            product.version += 1
            await self._session.flush()

        return variant

    async def update(
        self, company_id: UUID, variant_id: UUID, data: ProductVariantUpdate, expected_version: int
    ) -> ProductVariant:
        changes = data.model_dump(exclude_unset=True)
        if not changes:
            return await self.get(company_id, variant_id)
        if "size" in changes or "color" in changes:
            existing = await self.get(company_id, variant_id)
            size = changes.get("size", existing.size)
            color = changes.get("color", existing.color)
            changes["variant_name"] = _variant_name(size, color)

        stmt = (
            update(ProductVariant)
            .where(
                ProductVariant.id == variant_id,
                ProductVariant.company_id == company_id,
                ProductVariant.version == expected_version,
            )
            .values(**changes, version=ProductVariant.version + 1)
        )
        result = await self._session.execute(stmt)
        if affected_rows(result) == 0:
            still_present = await self._repo.get_by_id(company_id, variant_id)
            if still_present is None:
                raise NotFoundException("Product variant not found")
            raise ConflictException(
                "Product variant was modified by someone else. Reload and try again.",
                field="version",
            )
        await self._session.flush()
        return await self.get(company_id, variant_id)


class ProductBarcodeService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = ProductBarcodeRepository(session)
        self._variant_repo = ProductVariantRepository(session)

    async def list_for_variant(self, company_id: UUID, variant_id: UUID) -> list[ProductBarcode]:
        return await self._repo.list_for_variant(company_id, variant_id)

    async def add_barcode(
        self, company_id: UUID, variant_id: UUID, data: ProductBarcodeCreate
    ) -> ProductBarcode:
        variant = await self._variant_repo.get_by_id(company_id, variant_id)
        if variant is None:
            raise NotFoundException("Product variant not found")
        if await self._repo.get_by_barcode(company_id, data.barcode) is not None:
            raise ValidationException(f"Barcode '{data.barcode}' already exists", field="barcode")

        if data.is_primary:
            for existing_barcode in await self._repo.list_for_variant(company_id, variant_id):
                if existing_barcode.is_primary:
                    existing_barcode.is_primary = False

        barcode = ProductBarcode(
            id=uuid4(),
            company_id=company_id,
            product_variant_id=variant_id,
            barcode=data.barcode,
            barcode_type=data.barcode_type,
            is_primary=data.is_primary,
        )
        return await self._repo.create(barcode)


class ProductImageService:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._repo = ProductImageRepository(session)
        self._product_repo = ProductRepository(session)

    async def list_for_product(self, company_id: UUID, product_id: UUID) -> list[ProductImage]:
        return await self._repo.list_for_product(company_id, product_id)

    async def add_image(
        self, company_id: UUID, product_id: UUID, data: ProductImageCreate
    ) -> ProductImage:
        product = await self._product_repo.get_by_id(company_id, product_id)
        if product is None:
            raise NotFoundException("Product not found")

        if data.is_primary:
            for existing_image in await self._repo.list_for_product(company_id, product_id):
                if existing_image.is_primary:
                    existing_image.is_primary = False

        image = ProductImage(
            id=uuid4(),
            company_id=company_id,
            product_id=product_id,
            image_url=data.image_url,
            display_order=data.display_order,
            is_primary=data.is_primary,
        )
        return await self._repo.create(image)


@dataclass
class ProductImportRowResult:
    sku: str
    status: str  # "created" | "skipped" | "error"
    message: str | None = None


class ProductCsvService:
    """CSV export/import for Products — one row per variant, see
    csv_io.py for the wire format. Import is deliberately additive only:
    a SKU that already exists is reported as skipped rather than merged,
    keeping the reconciliation logic simple and predictable. Re-running
    the same file is therefore always safe.
    """

    def __init__(self, session: AsyncSession) -> None:
        self._session = session
        self._product_repo = ProductRepository(session)
        self._variant_repo = ProductVariantRepository(session)
        self._category_repo = CategoryRepository(session)
        self._brand_repo = BrandRepository(session)
        self._unit_repo = UnitRepository(session)
        self._product_service = ProductService(session)

    async def export_company_products(self, company_id: UUID) -> str:
        products = await self._product_repo.list_for_company(company_id)
        categories = {c.id: c.name for c in await self._category_repo.list_for_company(company_id)}
        brands = {b.id: b.name for b in await self._brand_repo.list_for_company(company_id)}
        units = {
            u.id: u.abbreviation
            for u in await self._unit_repo.list_available_for_company(company_id)
        }

        rows: list[ProductExportRow] = []
        for product in products:
            variants = await self._variant_repo.list_for_product(company_id, product.id)
            for variant in variants:
                rows.append(
                    ProductExportRow(
                        sku=product.sku,
                        name=product.name,
                        description=product.description,
                        category=categories.get(product.category_id)
                        if product.category_id
                        else None,
                        brand=brands.get(product.brand_id) if product.brand_id else None,
                        unit=units.get(product.base_unit_id, ""),
                        gender=product.gender.value if product.gender else None,
                        season=product.season,
                        age_group=product.age_group,
                        hsn_code=product.hsn_code,
                        tax_percent=product.tax_percent,
                        track_inventory=product.track_inventory,
                        allow_negative_stock=product.allow_negative_stock,
                        low_stock_threshold=product.low_stock_threshold,
                        is_active=product.is_active,
                        variant_sku=variant.sku,
                        size=variant.size,
                        color=variant.color,
                        purchase_price=variant.purchase_price,
                        selling_price=variant.selling_price,
                        mrp=variant.mrp,
                    )
                )
        return write_products_csv(rows)

    async def import_company_products(
        self, company_id: UUID, csv_text: str
    ) -> list[ProductImportRowResult]:
        groups = parse_products_csv(csv_text)

        results: list[ProductImportRowResult] = []
        for group in groups:
            if await self._product_repo.get_by_sku(company_id, group.sku) is not None:
                results.append(
                    ProductImportRowResult(
                        sku=group.sku,
                        status="skipped",
                        message="A product with this SKU already exists",
                    )
                )
                continue

            try:
                async with self._session.begin_nested():
                    await self._import_one_group(company_id, group)
                results.append(ProductImportRowResult(sku=group.sku, status="created"))
            except AppException as exc:
                results.append(
                    ProductImportRowResult(sku=group.sku, status="error", message=exc.message)
                )

        return results

    async def _import_one_group(self, company_id: UUID, group: ProductImportGroup) -> None:
        category_id = await self._resolve_category_id(company_id, group.category)
        brand_id = await self._resolve_brand_id(company_id, group.brand)
        unit = await self._resolve_unit(company_id, group.unit)
        gender = self._parse_gender(group.gender)

        has_variants = len(group.variants) > 1
        first_variant = group.variants[0]
        product_create = ProductCreate(
            sku=group.sku,
            name=group.name,
            description=group.description,
            category_id=category_id,
            brand_id=brand_id,
            base_unit_id=unit.id,
            gender=gender,
            season=group.season,
            age_group=group.age_group,
            hsn_code=group.hsn_code,
            tax_percent=group.tax_percent,
            track_inventory=group.track_inventory,
            allow_negative_stock=group.allow_negative_stock,
            low_stock_threshold=group.low_stock_threshold,
            has_variants=has_variants,
            purchase_price=first_variant.purchase_price,
            selling_price=first_variant.selling_price,
            mrp=first_variant.mrp,
            variants=[
                ProductVariantInput(
                    sku=v.variant_sku,
                    size=v.size,
                    color=v.color,
                    purchase_price=v.purchase_price,
                    selling_price=v.selling_price,
                    mrp=v.mrp,
                )
                for v in group.variants
            ]
            if has_variants
            else [],
        )
        await self._product_service.create(company_id, product_create)

    async def _resolve_category_id(self, company_id: UUID, name: str | None) -> UUID | None:
        if name is None:
            return None
        existing = await self._category_repo.get_by_name(company_id, name)
        if existing is not None:
            return existing.id
        created = await self._category_repo.create(
            Category(id=uuid4(), company_id=company_id, name=name)
        )
        return created.id

    async def _resolve_brand_id(self, company_id: UUID, name: str | None) -> UUID | None:
        if name is None:
            return None
        existing = await self._brand_repo.get_by_name(company_id, name)
        if existing is not None:
            return existing.id
        created = await self._brand_repo.create(Brand(id=uuid4(), company_id=company_id, name=name))
        return created.id

    async def _resolve_unit(self, company_id: UUID, abbreviation: str) -> Unit:
        for unit in await self._unit_repo.list_available_for_company(company_id):
            if unit.abbreviation == abbreviation:
                return unit
        raise ValidationException(f"Unknown unit '{abbreviation}'", field="unit")

    def _parse_gender(self, gender: str | None) -> ProductGender | None:
        if gender is None:
            return None
        try:
            return ProductGender(gender.lower())
        except ValueError as exc:
            valid = ", ".join(g.value for g in ProductGender)
            raise ValidationException(
                f"Unknown gender '{gender}' — expected one of: {valid}", field="gender"
            ) from exc
