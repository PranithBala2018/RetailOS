import 'package:freezed_annotation/freezed_annotation.dart';

import 'movement_type.dart';

part 'stock_transaction.freezed.dart';

@freezed
abstract class StockTransaction with _$StockTransaction {
  const factory StockTransaction({
    required String id,
    required String companyId,
    required String branchId,
    required String warehouseId,
    required String productVariantId,
    required MovementType movementType,
    required int quantityDelta,
    required int quantityAfter,
    String? reason,
    String? note,
    String? transferId,
    required DateTime createdAt,
  }) = _StockTransaction;
}
