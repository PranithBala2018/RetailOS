import 'package:freezed_annotation/freezed_annotation.dart';

import 'barcode_type.dart';

part 'product_barcode.freezed.dart';

@freezed
abstract class ProductBarcode with _$ProductBarcode {
  const factory ProductBarcode({
    required String id,
    required String companyId,
    required String productVariantId,
    required String barcode,
    required BarcodeType barcodeType,
    required bool isPrimary,
  }) = _ProductBarcode;
}
