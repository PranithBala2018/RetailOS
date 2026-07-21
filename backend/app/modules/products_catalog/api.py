"""Categories, Brands, Units, Products, Variants, Barcodes, Images
endpoints — every route is scoped to `current_user.company_id` and gated
behind the `categories.*`/`brands.*`/`units.*`/`products.*` permission
codes seeded in `0a79316d69b0_seed_products_catalog_permissions.py`.
"""

from typing import Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.common.response import success_envelope
from app.core.db import get_db_session
from app.modules.auth.dependencies import require_permission
from app.modules.products_catalog.schemas import (
    BrandCreate,
    BrandRead,
    BrandUpdate,
    CategoryCreate,
    CategoryRead,
    CategoryUpdate,
    ProductBarcodeCreate,
    ProductBarcodeRead,
    ProductCreate,
    ProductImageCreate,
    ProductImageRead,
    ProductRead,
    ProductUpdate,
    ProductVariantInput,
    ProductVariantRead,
    ProductVariantUpdate,
    ProductWithVariantsRead,
    UnitCreate,
    UnitRead,
)
from app.modules.products_catalog.service import (
    BrandService,
    CategoryService,
    ProductBarcodeService,
    ProductImageService,
    ProductService,
    ProductVariantService,
    UnitService,
)
from app.modules.users_roles_permissions.models import User

router = APIRouter(tags=["products_catalog"])


# --- Categories ---


@router.get("/categories")
async def list_categories(
    current_user: User = Depends(require_permission("categories.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    categories = await CategoryService(session).list_for_company(current_user.company_id)
    return success_envelope(
        data=[CategoryRead.model_validate(c).model_dump(mode="json") for c in categories]
    )


@router.post("/categories")
async def create_category(
    data: CategoryCreate,
    current_user: User = Depends(require_permission("categories.create")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    category = await CategoryService(session).create(current_user.company_id, data)
    return success_envelope(
        data=CategoryRead.model_validate(category).model_dump(mode="json"),
        message="Category created",
    )


@router.get("/categories/{category_id}")
async def get_category(
    category_id: UUID,
    current_user: User = Depends(require_permission("categories.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    category = await CategoryService(session).get(current_user.company_id, category_id)
    return success_envelope(data=CategoryRead.model_validate(category).model_dump(mode="json"))


@router.put("/categories/{category_id}")
async def update_category(
    category_id: UUID,
    data: CategoryUpdate,
    expected_version: int,
    current_user: User = Depends(require_permission("categories.update")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    category = await CategoryService(session).update(
        current_user.company_id, category_id, data, expected_version
    )
    return success_envelope(
        data=CategoryRead.model_validate(category).model_dump(mode="json"),
        message="Category updated",
    )


# --- Brands ---


@router.get("/brands")
async def list_brands(
    current_user: User = Depends(require_permission("brands.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    brands = await BrandService(session).list_for_company(current_user.company_id)
    return success_envelope(
        data=[BrandRead.model_validate(b).model_dump(mode="json") for b in brands]
    )


@router.post("/brands")
async def create_brand(
    data: BrandCreate,
    current_user: User = Depends(require_permission("brands.create")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    brand = await BrandService(session).create(current_user.company_id, data)
    return success_envelope(
        data=BrandRead.model_validate(brand).model_dump(mode="json"), message="Brand created"
    )


@router.get("/brands/{brand_id}")
async def get_brand(
    brand_id: UUID,
    current_user: User = Depends(require_permission("brands.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    brand = await BrandService(session).get(current_user.company_id, brand_id)
    return success_envelope(data=BrandRead.model_validate(brand).model_dump(mode="json"))


@router.put("/brands/{brand_id}")
async def update_brand(
    brand_id: UUID,
    data: BrandUpdate,
    expected_version: int,
    current_user: User = Depends(require_permission("brands.update")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    brand = await BrandService(session).update(
        current_user.company_id, brand_id, data, expected_version
    )
    return success_envelope(
        data=BrandRead.model_validate(brand).model_dump(mode="json"), message="Brand updated"
    )


# --- Units ---


@router.get("/units")
async def list_units(
    current_user: User = Depends(require_permission("units.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    units = await UnitService(session).list_available_for_company(current_user.company_id)
    return success_envelope(
        data=[UnitRead.model_validate(u).model_dump(mode="json") for u in units]
    )


@router.post("/units")
async def create_unit(
    data: UnitCreate,
    current_user: User = Depends(require_permission("units.create")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    unit = await UnitService(session).create(current_user.company_id, data)
    return success_envelope(
        data=UnitRead.model_validate(unit).model_dump(mode="json"), message="Unit created"
    )


# --- Products ---


@router.get("/products")
async def list_products(
    search: str | None = Query(default=None),
    category_id: UUID | None = Query(default=None),
    current_user: User = Depends(require_permission("products.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    products = await ProductService(session).list_for_company(
        current_user.company_id, search=search, category_id=category_id
    )
    return success_envelope(
        data=[ProductRead.model_validate(p).model_dump(mode="json") for p in products]
    )


@router.post("/products")
async def create_product(
    data: ProductCreate,
    current_user: User = Depends(require_permission("products.create")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    product, variants = await ProductService(session).create(current_user.company_id, data)
    return success_envelope(
        data=ProductWithVariantsRead(
            product=ProductRead.model_validate(product),
            variants=[ProductVariantRead.model_validate(v) for v in variants],
        ).model_dump(mode="json"),
        message="Product created",
    )


@router.get("/products/{product_id}")
async def get_product(
    product_id: UUID,
    current_user: User = Depends(require_permission("products.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    product, variants = await ProductService(session).get_with_variants(
        current_user.company_id, product_id
    )
    return success_envelope(
        data=ProductWithVariantsRead(
            product=ProductRead.model_validate(product),
            variants=[ProductVariantRead.model_validate(v) for v in variants],
        ).model_dump(mode="json")
    )


@router.put("/products/{product_id}")
async def update_product(
    product_id: UUID,
    data: ProductUpdate,
    expected_version: int,
    current_user: User = Depends(require_permission("products.update")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    product = await ProductService(session).update(
        current_user.company_id, product_id, data, expected_version
    )
    return success_envelope(
        data=ProductRead.model_validate(product).model_dump(mode="json"), message="Product updated"
    )


@router.delete("/products/{product_id}")
async def disable_product(
    product_id: UUID,
    expected_version: int,
    current_user: User = Depends(require_permission("products.delete")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    await ProductService(session).update(
        current_user.company_id, product_id, ProductUpdate(is_active=False), expected_version
    )
    return success_envelope(message="Product disabled")


# --- Product Variants ---


@router.get("/products/{product_id}/variants")
async def list_product_variants(
    product_id: UUID,
    current_user: User = Depends(require_permission("products.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    variants = await ProductVariantService(session).list_for_product(
        current_user.company_id, product_id
    )
    return success_envelope(
        data=[ProductVariantRead.model_validate(v).model_dump(mode="json") for v in variants]
    )


@router.post("/products/{product_id}/variants")
async def add_product_variant(
    product_id: UUID,
    data: ProductVariantInput,
    current_user: User = Depends(require_permission("products.update")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    variant = await ProductVariantService(session).add_variant(
        current_user.company_id, product_id, data
    )
    return success_envelope(
        data=ProductVariantRead.model_validate(variant).model_dump(mode="json"),
        message="Variant added",
    )


@router.put("/product-variants/{variant_id}")
async def update_product_variant(
    variant_id: UUID,
    data: ProductVariantUpdate,
    expected_version: int,
    current_user: User = Depends(require_permission("products.update")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    variant = await ProductVariantService(session).update(
        current_user.company_id, variant_id, data, expected_version
    )
    return success_envelope(
        data=ProductVariantRead.model_validate(variant).model_dump(mode="json"),
        message="Variant updated",
    )


# --- Product Barcodes ---


@router.get("/product-variants/{variant_id}/barcodes")
async def list_variant_barcodes(
    variant_id: UUID,
    current_user: User = Depends(require_permission("products.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    barcodes = await ProductBarcodeService(session).list_for_variant(
        current_user.company_id, variant_id
    )
    return success_envelope(
        data=[ProductBarcodeRead.model_validate(b).model_dump(mode="json") for b in barcodes]
    )


@router.post("/product-variants/{variant_id}/barcodes")
async def add_variant_barcode(
    variant_id: UUID,
    data: ProductBarcodeCreate,
    current_user: User = Depends(require_permission("products.update")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    barcode = await ProductBarcodeService(session).add_barcode(
        current_user.company_id, variant_id, data
    )
    return success_envelope(
        data=ProductBarcodeRead.model_validate(barcode).model_dump(mode="json"),
        message="Barcode added",
    )


# --- Product Images ---


@router.get("/products/{product_id}/images")
async def list_product_images(
    product_id: UUID,
    current_user: User = Depends(require_permission("products.read")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    images = await ProductImageService(session).list_for_product(
        current_user.company_id, product_id
    )
    return success_envelope(
        data=[ProductImageRead.model_validate(i).model_dump(mode="json") for i in images]
    )


@router.post("/products/{product_id}/images")
async def add_product_image(
    product_id: UUID,
    data: ProductImageCreate,
    current_user: User = Depends(require_permission("products.update")),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, Any]:
    image = await ProductImageService(session).add_image(current_user.company_id, product_id, data)
    return success_envelope(
        data=ProductImageRead.model_validate(image).model_dump(mode="json"), message="Image added"
    )
