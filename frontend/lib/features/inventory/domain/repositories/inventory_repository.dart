import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/movement_type.dart';
import '../entities/stock_level.dart';
import '../entities/stock_transaction.dart';
import '../entities/stock_transfer.dart';
import '../entities/transaction_page.dart';
import '../entities/warehouse.dart';

class StockInParams {
  const StockInParams({
    required this.warehouseId,
    required this.productVariantId,
    required this.quantity,
    this.reason,
    this.note,
  });

  final String warehouseId;
  final String productVariantId;
  final int quantity;
  final String? reason;
  final String? note;
}

class StockOutParams {
  const StockOutParams({
    required this.warehouseId,
    required this.productVariantId,
    required this.quantity,
    this.reason,
    this.note,
  });

  final String warehouseId;
  final String productVariantId;
  final int quantity;
  final String? reason;
  final String? note;
}

class AdjustmentParams {
  const AdjustmentParams({
    required this.warehouseId,
    required this.productVariantId,
    required this.countedQuantity,
    required this.reason,
    this.note,
  });

  final String warehouseId;
  final String productVariantId;
  final int countedQuantity;
  final String reason;
  final String? note;
}

class TransferParams {
  const TransferParams({
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.productVariantId,
    required this.quantity,
    this.note,
  });

  final String fromWarehouseId;
  final String toWarehouseId;
  final String productVariantId;
  final int quantity;
  final String? note;
}

/// Client for the Inventory backend module (Stock In/Out/Transfer/
/// Adjustment, current-stock/low-stock queries, the transaction ledger)
/// — see backend/app/modules/inventory/api.py for the exact wire
/// contract this mirrors. `listWarehouses` proxies the company module's
/// `GET /warehouses` (see that endpoint's docstring for why it lives
/// there) since Inventory is the only Flutter feature needing it today.
abstract interface class InventoryRepository {
  Future<Either<Failure, List<Warehouse>>> listWarehouses();

  Future<Either<Failure, List<StockLevel>>> listStock({
    String? warehouseId,
    String? search,
    String? categoryId,
    bool lowStockOnly = false,
  });

  Future<Either<Failure, StockLevel>> getStockLevel(
    String productVariantId, {
    String? warehouseId,
  });

  Future<Either<Failure, List<StockLevel>>> listLowStock({String? warehouseId});

  Future<Either<Failure, StockTransaction>> stockIn(StockInParams params);
  Future<Either<Failure, StockTransaction>> stockOut(StockOutParams params);
  Future<Either<Failure, StockTransaction>> adjust(AdjustmentParams params);
  Future<Either<Failure, StockTransfer>> transfer(TransferParams params);

  Future<Either<Failure, TransactionPage>> listTransactions({
    String? warehouseId,
    String? productVariantId,
    MovementType? movementType,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? cursor,
    int limit = 25,
  });
}
