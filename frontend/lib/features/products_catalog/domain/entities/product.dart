import 'package:freezed_annotation/freezed_annotation.dart';

import 'product_gender.dart';

part 'product.freezed.dart';

@freezed
abstract class Product with _$Product {
  const factory Product({
    required String id,
    required String companyId,
    required String sku,
    required String name,
    String? description,
    String? categoryId,
    String? brandId,
    required String baseUnitId,
    ProductGender? gender,
    String? season,
    String? ageGroup,
    String? hsnCode,
    String? taxPercent,
    required bool hasVariants,
    required bool trackInventory,
    required bool allowNegativeStock,
    int? lowStockThreshold,
    required bool isActive,
    required int version,
  }) = _Product;
}
