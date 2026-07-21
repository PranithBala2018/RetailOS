"""Categories, Brands, Units, Products, Variants, Barcodes, Images.

Every product has at least one variant — even a "simple" product with no
real size/color combinations gets exactly one auto-created variant (see
service.py). Pricing, stock (once Inventory exists), and barcodes always
hang off `product_variants`, never off `products` directly. This is a
deliberate simplification: without it, every downstream module (POS,
Inventory) would need two code paths — "does this product have variants
or not" — for what is otherwise identical logic. It's also what makes
the Kids Wear pilot's Size/Color/Age Group/Season/Gender attributes
(SPRINT0 Sprint 2 brief) fall out naturally: Gender/Season/Age Group
classify the *product* (a listing), Size/Color distinguish its
*variants* — no schema change was needed to support this in Sprint 3.
"""

import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
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


class ProductGender(StrEnum):
    MEN = "men"
    WOMEN = "women"
    KIDS = "kids"
    UNISEX = "unisex"


class BarcodeType(StrEnum):
    EAN13 = "ean13"
    UPC_A = "upc_a"
    CODE128 = "code128"
    INTERNAL = "internal"


class Category(
    Base,
    IdMixin,
    CompanyScopedMixin,
    TimestampMixin,
    SoftDeleteMixin,
    ConcurrencyMixin,
    SyncMixin,
    AuditMixin,
):
    __tablename__ = "categories"
    __table_args__ = (UniqueConstraint("company_id", "name", name="uq_categories_company_id_name"),)

    name: Mapped[str] = mapped_column(String(150))
    # Self-referential — safe to declare inline (no use_alter needed):
    # the table isn't circularly dependent on any *other* table the way
    # branches/users/warehouses were in Sprint 2.
    parent_category_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("categories.id"), nullable=True
    )
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    display_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class Brand(
    Base,
    IdMixin,
    CompanyScopedMixin,
    TimestampMixin,
    SoftDeleteMixin,
    ConcurrencyMixin,
    SyncMixin,
    AuditMixin,
):
    __tablename__ = "brands"
    __table_args__ = (UniqueConstraint("company_id", "name", name="uq_brands_company_id_name"),)

    name: Mapped[str] = mapped_column(String(150))
    logo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class Unit(Base, IdMixin, TimestampMixin, SoftDeleteMixin, ConcurrencyMixin, AuditMixin):
    """`company_id` nullable — NULL means a system default unit (Pcs, Kg,
    Litre, ...), seeded once and shared by every tenant, same pattern as
    `Role` in Sprint 2. A real UUID means a company-specific custom unit.
    """

    __tablename__ = "units"
    __table_args__ = (
        UniqueConstraint("company_id", "abbreviation", name="uq_units_company_id_abbr"),
    )

    company_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("companies.id"), nullable=True, index=True
    )
    name: Mapped[str] = mapped_column(String(100))
    abbreviation: Mapped[str] = mapped_column(String(20))
    is_system: Mapped[bool] = mapped_column(Boolean, default=False)


class Product(
    Base,
    IdMixin,
    CompanyScopedMixin,
    TimestampMixin,
    SoftDeleteMixin,
    ConcurrencyMixin,
    SyncMixin,
    AuditMixin,
):
    __tablename__ = "products"
    __table_args__ = (UniqueConstraint("company_id", "sku", name="uq_products_company_id_sku"),)

    # The "master" SKU — for a no-variant product this is also its single
    # variant's SKU; for a variant-bearing product this identifies the
    # listing, and each variant gets its own SKU (see ProductVariant).
    sku: Mapped[str] = mapped_column(String(100), index=True)
    name: Mapped[str] = mapped_column(String(200), index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    category_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("categories.id"), nullable=True, index=True
    )
    brand_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("brands.id"), nullable=True, index=True
    )
    base_unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("units.id"))

    # Kids Wear pilot prep (SPRINT0 Sprint 2 brief) — product-level
    # classification. Size/Color live on the variant instead.
    gender: Mapped[ProductGender | None] = mapped_column(
        Enum(
            ProductGender,
            native_enum=False,
            length=20,
            validate_strings=True,
            values_callable=lambda enum_cls: [member.value for member in enum_cls],
        ),
        nullable=True,
    )
    season: Mapped[str | None] = mapped_column(String(50), nullable=True)
    age_group: Mapped[str | None] = mapped_column(String(50), nullable=True)

    hsn_code: Mapped[str | None] = mapped_column(String(20), nullable=True)
    tax_percent: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)

    has_variants: Mapped[bool] = mapped_column(Boolean, default=False)
    track_inventory: Mapped[bool] = mapped_column(Boolean, default=True)
    allow_negative_stock: Mapped[bool] = mapped_column(Boolean, default=False)
    low_stock_threshold: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class ProductVariant(
    Base,
    IdMixin,
    CompanyScopedMixin,
    TimestampMixin,
    SoftDeleteMixin,
    ConcurrencyMixin,
    SyncMixin,
    AuditMixin,
):
    """Every product has >=1 row here — see the module docstring."""

    __tablename__ = "product_variants"
    __table_args__ = (
        UniqueConstraint("company_id", "sku", name="uq_product_variants_company_id_sku"),
    )

    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("products.id"), nullable=False, index=True
    )
    sku: Mapped[str] = mapped_column(String(100), index=True)
    size: Mapped[str | None] = mapped_column(String(50), nullable=True)
    color: Mapped[str | None] = mapped_column(String(50), nullable=True)
    # Display label, e.g. "Red / Medium" — generated at creation time
    # (service.py), stored rather than computed so it survives independent
    # of size/color being renamed later without a migration.
    variant_name: Mapped[str | None] = mapped_column(String(150), nullable=True)

    purchase_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0)
    selling_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=0)
    mrp: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class ProductBarcode(
    Base,
    IdMixin,
    CompanyScopedMixin,
    TimestampMixin,
    SoftDeleteMixin,
    ConcurrencyMixin,
    SyncMixin,
    AuditMixin,
):
    __tablename__ = "product_barcodes"
    __table_args__ = (
        UniqueConstraint("company_id", "barcode", name="uq_product_barcodes_company_id_barcode"),
    )

    product_variant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("product_variants.id"), nullable=False, index=True
    )
    barcode: Mapped[str] = mapped_column(String(100), index=True)
    barcode_type: Mapped[BarcodeType] = mapped_column(
        Enum(
            BarcodeType,
            native_enum=False,
            length=20,
            validate_strings=True,
            values_callable=lambda enum_cls: [member.value for member in enum_cls],
        ),
        default=BarcodeType.INTERNAL,
    )
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)


class ProductImage(Base, IdMixin, CompanyScopedMixin, TimestampMixin, AuditMixin):
    """Product-level, not variant-level — per-variant imagery is a future
    enhancement, not needed for Sprint 3's scope."""

    __tablename__ = "product_images"

    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("products.id"), nullable=False, index=True
    )
    image_url: Mapped[str] = mapped_column(String(500))
    display_order: Mapped[int] = mapped_column(Integer, default=0)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
