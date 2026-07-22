import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_variant.freezed.dart';

/// Prices are kept as the raw wire-format `String` (e.g. `"120.00"`),
/// matching the backend's `Decimal` -> JSON-string serialization — see
/// backend/app/modules/products_catalog/schemas.py. This avoids float
/// rounding entirely; arithmetic/formatting happens at the point of use
/// via `core/utils/money_format.dart`, not in the entity.
@freezed
abstract class ProductVariant with _$ProductVariant {
  const factory ProductVariant({
    required String id,
    required String companyId,
    required String productId,
    required String sku,
    String? size,
    String? color,
    String? variantName,
    required String purchasePrice,
    required String sellingPrice,
    String? mrp,
    required bool isActive,
    required int version,
  }) = _ProductVariant;
}
