import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_image.freezed.dart';

@freezed
abstract class ProductImage with _$ProductImage {
  const factory ProductImage({
    required String id,
    required String companyId,
    required String productId,
    required String imageUrl,
    required int displayOrder,
    required bool isPrimary,
  }) = _ProductImage;
}
