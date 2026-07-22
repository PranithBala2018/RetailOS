import 'package:freezed_annotation/freezed_annotation.dart';

import 'product.dart';
import 'product_variant.dart';

part 'product_with_variants.freezed.dart';

@freezed
abstract class ProductWithVariants with _$ProductWithVariants {
  const factory ProductWithVariants({
    required Product product,
    required List<ProductVariant> variants,
  }) = _ProductWithVariants;
}
