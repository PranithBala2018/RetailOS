"""CSV parsing/writing for Product import/export.

Wire format is deliberately flat and denormalized — one row per product
variant, with category/brand/unit referenced by human-readable name
rather than a UUID, so a merchant can prepare or edit the file in a
spreadsheet without looking up any ids. Rows sharing the same `sku` are
grouped into one product with multiple variants on import.
"""

import csv
import io
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation

EXPORT_COLUMNS = [
    "sku",
    "name",
    "description",
    "category",
    "brand",
    "unit",
    "gender",
    "season",
    "age_group",
    "hsn_code",
    "tax_percent",
    "track_inventory",
    "allow_negative_stock",
    "low_stock_threshold",
    "is_active",
    "variant_sku",
    "size",
    "color",
    "purchase_price",
    "selling_price",
    "mrp",
]

_REQUIRED_IMPORT_COLUMNS = {"sku", "name", "unit", "variant_sku", "purchase_price", "selling_price"}


@dataclass
class ProductExportRow:
    sku: str
    name: str
    description: str | None
    category: str | None
    brand: str | None
    unit: str
    gender: str | None
    season: str | None
    age_group: str | None
    hsn_code: str | None
    tax_percent: Decimal | None
    track_inventory: bool
    allow_negative_stock: bool
    low_stock_threshold: int | None
    is_active: bool
    variant_sku: str
    size: str | None
    color: str | None
    purchase_price: Decimal
    selling_price: Decimal
    mrp: Decimal | None


def write_products_csv(rows: list[ProductExportRow]) -> str:
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=EXPORT_COLUMNS)
    writer.writeheader()
    for row in rows:
        writer.writerow({col: _serialize(getattr(row, col)) for col in EXPORT_COLUMNS})
    return buffer.getvalue()


def _serialize(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


class CsvImportError(Exception):
    """A row-level parse error, carrying its 1-based line number (0 for
    file-level errors like a missing header)."""

    def __init__(self, line_number: int, message: str) -> None:
        super().__init__(message)
        self.line_number = line_number
        self.message = message


@dataclass
class ProductImportVariantRow:
    line_number: int
    variant_sku: str
    size: str | None
    color: str | None
    purchase_price: Decimal
    selling_price: Decimal
    mrp: Decimal | None


@dataclass
class ProductImportGroup:
    sku: str
    name: str
    description: str | None
    category: str | None
    brand: str | None
    unit: str
    gender: str | None
    season: str | None
    age_group: str | None
    hsn_code: str | None
    tax_percent: Decimal | None
    track_inventory: bool
    allow_negative_stock: bool
    low_stock_threshold: int | None
    variants: list[ProductImportVariantRow] = field(default_factory=list)


def parse_products_csv(csv_text: str) -> list[ProductImportGroup]:
    reader = csv.DictReader(io.StringIO(csv_text))
    if reader.fieldnames is None:
        raise CsvImportError(0, "CSV file has no header row")

    missing = _REQUIRED_IMPORT_COLUMNS - set(reader.fieldnames)
    if missing:
        raise CsvImportError(0, f"Missing required column(s): {', '.join(sorted(missing))}")

    groups: dict[str, ProductImportGroup] = {}
    for line_number, raw_row in enumerate(reader, start=2):  # header occupies line 1
        sku = _clean(raw_row.get("sku"))
        if not sku:
            raise CsvImportError(line_number, "sku is required")

        variant = ProductImportVariantRow(
            line_number=line_number,
            variant_sku=_clean(raw_row.get("variant_sku")) or sku,
            size=_none_if_blank(raw_row.get("size")),
            color=_none_if_blank(raw_row.get("color")),
            purchase_price=_parse_decimal(
                line_number, raw_row.get("purchase_price"), "purchase_price"
            ),
            selling_price=_parse_decimal(
                line_number, raw_row.get("selling_price"), "selling_price"
            ),
            mrp=_parse_optional_decimal(line_number, raw_row.get("mrp"), "mrp"),
        )

        group = groups.get(sku)
        if group is None:
            unit = _clean(raw_row.get("unit"))
            if not unit:
                raise CsvImportError(line_number, "unit is required")
            name = _clean(raw_row.get("name"))
            if not name:
                raise CsvImportError(line_number, "name is required")

            group = ProductImportGroup(
                sku=sku,
                name=name,
                description=_none_if_blank(raw_row.get("description")),
                category=_none_if_blank(raw_row.get("category")),
                brand=_none_if_blank(raw_row.get("brand")),
                unit=unit,
                gender=_none_if_blank(raw_row.get("gender")),
                season=_none_if_blank(raw_row.get("season")),
                age_group=_none_if_blank(raw_row.get("age_group")),
                hsn_code=_none_if_blank(raw_row.get("hsn_code")),
                tax_percent=_parse_optional_decimal(
                    line_number, raw_row.get("tax_percent"), "tax_percent"
                ),
                track_inventory=_parse_bool(raw_row.get("track_inventory"), default=True),
                allow_negative_stock=_parse_bool(
                    raw_row.get("allow_negative_stock"), default=False
                ),
                low_stock_threshold=_parse_optional_int(
                    line_number, raw_row.get("low_stock_threshold"), "low_stock_threshold"
                ),
            )
            groups[sku] = group

        group.variants.append(variant)

    return list(groups.values())


def _clean(value: str | None) -> str:
    return (value or "").strip()


def _none_if_blank(value: str | None) -> str | None:
    cleaned = _clean(value)
    return cleaned or None


def _parse_bool(value: str | None, *, default: bool) -> bool:
    cleaned = _clean(value).lower()
    if not cleaned:
        return default
    return cleaned in {"true", "1", "yes", "y"}


def _parse_decimal(line_number: int, value: str | None, field_name: str) -> Decimal:
    cleaned = _clean(value)
    if not cleaned:
        raise CsvImportError(line_number, f"{field_name} is required")
    try:
        return Decimal(cleaned)
    except InvalidOperation as exc:
        raise CsvImportError(
            line_number, f"{field_name} '{cleaned}' is not a valid number"
        ) from exc


def _parse_optional_decimal(line_number: int, value: str | None, field_name: str) -> Decimal | None:
    cleaned = _clean(value)
    if not cleaned:
        return None
    try:
        return Decimal(cleaned)
    except InvalidOperation as exc:
        raise CsvImportError(
            line_number, f"{field_name} '{cleaned}' is not a valid number"
        ) from exc


def _parse_optional_int(line_number: int, value: str | None, field_name: str) -> int | None:
    cleaned = _clean(value)
    if not cleaned:
        return None
    try:
        return int(cleaned)
    except ValueError as exc:
        raise CsvImportError(
            line_number, f"{field_name} '{cleaned}' is not a valid integer"
        ) from exc
