import 'package:freezed_annotation/freezed_annotation.dart';

part 'stock_transfer.freezed.dart';

@freezed
abstract class StockTransfer with _$StockTransfer {
  const factory StockTransfer({
    required String id,
    required String companyId,
    required String fromWarehouseId,
    required String toWarehouseId,
    required String productVariantId,
    required int quantity,
    String? note,
    required DateTime createdAt,
  }) = _StockTransfer;
}
