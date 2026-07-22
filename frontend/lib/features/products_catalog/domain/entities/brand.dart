import 'package:freezed_annotation/freezed_annotation.dart';

part 'brand.freezed.dart';

@freezed
abstract class Brand with _$Brand {
  const factory Brand({
    required String id,
    required String companyId,
    required String name,
    String? logoUrl,
    String? description,
    required bool isActive,
    required int version,
  }) = _Brand;
}
