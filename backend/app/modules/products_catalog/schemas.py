"""Pydantic request/response schemas for Categories, Brands, Units,
Products, Variants, Barcodes, Images.
"""

from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field

from app.common.schemas import ORMSchema
from app.modules.products_catalog.models import BarcodeType, ProductGender


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    parent_category_id: UUID | None = None
    description: str | None = None
    image_url: str | None = Field(default=None, max_length=500)
    display_order: int = 0


class CategoryUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=150)
    parent_category_id: UUID | None = None
    description: str | None = None
    image_url: str | None = Field(default=None, max_length=500)
    display_order: int | None = None
    is_active: bool | None = None


class CategoryRead(ORMSchema):
    id: UUID
    company_id: UUID
    name: str
    parent_category_id: UUID | None
    description: str | None
    image_url: str | None
    display_order: int
    is_active: bool
    version: int


class BrandCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    logo_url: str | None = Field(default=None, max_length=500)
    description: str | None = None


class BrandUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=150)
    logo_url: str | None = Field(default=None, max_length=500)
    description: str | None = None
    is_active: bool | None = None


class BrandRead(ORMSchema):
    id: UUID
    company_id: UUID
    name: str
    logo_url: str | None
    description: str | None
    is_active: bool
    version: int


class UnitCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    abbreviation: str = Field(min_length=1, max_length=20)


class UnitRead(ORMSchema):
    id: UUID
    company_id: UUID | None
    name: str
    abbreviation: str
    is_system: bool


class ProductVariantInput(BaseModel):
    """Used both standalone (POST .../variants) and nested inside
    ProductCreate for has_variants=True products."""

    sku: str = Field(min_length=1, max_length=100)
    size: str | None = Field(default=None, max_length=50)
    color: str | None = Field(default=None, max_length=50)
    purchase_price: Decimal = Field(default=Decimal(0), ge=0)
    selling_price: Decimal = Field(default=Decimal(0), ge=0)
    mrp: Decimal | None = Field(default=None, ge=0)


class ProductVariantUpdate(BaseModel):
    size: str | None = Field(default=None, max_length=50)
    color: str | None = Field(default=None, max_length=50)
    purchase_price: Decimal | None = Field(default=None, ge=0)
    selling_price: Decimal | None = Field(default=None, ge=0)
    mrp: Decimal | None = Field(default=None, ge=0)
    is_active: bool | None = None


class ProductVariantRead(ORMSchema):
    id: UUID
    company_id: UUID
    product_id: UUID
    sku: str
    size: str | None
    color: str | None
    variant_name: str | None
    purchase_price: Decimal
    selling_price: Decimal
    mrp: Decimal | None
    is_active: bool
    version: int


class ProductCreate(BaseModel):
    sku: str = Field(min_length=1, max_length=100)
    name: str = Field(min_length=1, max_length=200)
    description: str | None = None
    category_id: UUID | None = None
    brand_id: UUID | None = None
    base_unit_id: UUID
    gender: ProductGender | None = None
    season: str | None = Field(default=None, max_length=50)
    age_group: str | None = Field(default=None, max_length=50)
    hsn_code: str | None = Field(default=None, max_length=20)
    tax_percent: Decimal | None = Field(default=None, ge=0, le=100)
    track_inventory: bool = True
    allow_negative_stock: bool = False
    low_stock_threshold: int | None = Field(default=None, ge=0)

    has_variants: bool = False
    # Used when has_variants=False — a single implicit variant is
    # created from these. Ignored (variants list is authoritative)
    # when has_variants=True.
    purchase_price: Decimal = Field(default=Decimal(0), ge=0)
    selling_price: Decimal = Field(default=Decimal(0), ge=0)
    mrp: Decimal | None = Field(default=None, ge=0)
    variants: list[ProductVariantInput] = Field(default_factory=list)


class ProductUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    category_id: UUID | None = None
    brand_id: UUID | None = None
    gender: ProductGender | None = None
    season: str | None = Field(default=None, max_length=50)
    age_group: str | None = Field(default=None, max_length=50)
    hsn_code: str | None = Field(default=None, max_length=20)
    tax_percent: Decimal | None = Field(default=None, ge=0, le=100)
    track_inventory: bool | None = None
    allow_negative_stock: bool | None = None
    low_stock_threshold: int | None = Field(default=None, ge=0)
    is_active: bool | None = None


class ProductRead(ORMSchema):
    id: UUID
    company_id: UUID
    sku: str
    name: str
    description: str | None
    category_id: UUID | None
    brand_id: UUID | None
    base_unit_id: UUID
    gender: ProductGender | None
    season: str | None
    age_group: str | None
    hsn_code: str | None
    tax_percent: Decimal | None
    has_variants: bool
    track_inventory: bool
    allow_negative_stock: bool
    low_stock_threshold: int | None
    is_active: bool
    version: int


class ProductWithVariantsRead(BaseModel):
    product: ProductRead
    variants: list[ProductVariantRead]


class ProductBarcodeCreate(BaseModel):
    barcode: str = Field(min_length=1, max_length=100)
    barcode_type: BarcodeType = BarcodeType.INTERNAL
    is_primary: bool = False


class ProductBarcodeRead(ORMSchema):
    id: UUID
    company_id: UUID
    product_variant_id: UUID
    barcode: str
    barcode_type: BarcodeType
    is_primary: bool


class ProductImageCreate(BaseModel):
    image_url: str = Field(min_length=1, max_length=500)
    display_order: int = 0
    is_primary: bool = False


class ProductImageRead(ORMSchema):
    id: UUID
    company_id: UUID
    product_id: UUID
    image_url: str
    display_order: int
    is_primary: bool
