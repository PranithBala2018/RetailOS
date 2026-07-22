import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';

@freezed
abstract class Category with _$Category {
  const factory Category({
    required String id,
    required String companyId,
    required String name,
    String? parentCategoryId,
    String? description,
    String? imageUrl,
    required int displayOrder,
    required bool isActive,
    required int version,
  }) = _Category;
}
