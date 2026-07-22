import 'package:freezed_annotation/freezed_annotation.dart';

part 'stock_level.freezed.dart';

/// Assembled server-side from `StockLevelSummary` (backend
/// `inventory/service.py`) — spans a stock balance plus just enough
/// product/variant context for the stock list screen, so this entity
/// mirrors that flattened shape rather than the raw `stock_levels` row.
@freezed
abstract class StockLevel with _$StockLevel {
  const factory StockLevel({
    String? warehouseId,
    required String productId,
    required String productVariantId,
    required String sku,
    required String productName,
    String? variantName,
    int? lowStockThreshold,
    required int quantity,
    required bool isLowStock,
  }) = _StockLevel;
}
