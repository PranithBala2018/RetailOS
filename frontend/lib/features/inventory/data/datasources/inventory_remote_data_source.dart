import 'package:dio/dio.dart';

import '../../domain/entities/movement_type.dart';
import '../../domain/entities/stock_level.dart';
import '../../domain/entities/stock_transaction.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/entities/transaction_page.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/repositories/inventory_repository.dart';

/// Raw API calls only — parses the `{"success", "message", "data"}`
/// envelope (API.md) directly into domain entities, matching the
/// pattern set in features/products_catalog.
class InventoryRemoteDataSource {
  InventoryRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Warehouse>> listWarehouses() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/warehouses');
    final items = response.data!['data'] as List<dynamic>;
    return items.cast<Map<String, dynamic>>().map(_warehouseFromJson).toList();
  }

  Warehouse _warehouseFromJson(Map<String, dynamic> data) => Warehouse(
    id: data['id'] as String,
    companyId: data['company_id'] as String,
    branchId: data['branch_id'] as String,
    name: data['name'] as String,
    code: data['code'] as String,
    isDefault: data['is_default'] as bool,
    isActive: data['is_active'] as bool,
  );

  Future<List<StockLevel>> listStock({
    String? warehouseId,
    String? search,
    String? categoryId,
    bool lowStockOnly = false,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/inventory/stock',
      queryParameters: {
        'warehouse_id': ?warehouseId,
        if (search != null && search.isNotEmpty) 'search': search,
        'category_id': ?categoryId,
        'low_stock_only': lowStockOnly,
      },
    );
    final items = response.data!['data'] as List<dynamic>;
    return items.cast<Map<String, dynamic>>().map(_stockLevelFromJson).toList();
  }

  Future<StockLevel> getStockLevel(
    String productVariantId, {
    String? warehouseId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/inventory/stock/$productVariantId',
      queryParameters: {'warehouse_id': ?warehouseId},
    );
    return _stockLevelFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<List<StockLevel>> listLowStock({String? warehouseId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/inventory/low-stock',
      queryParameters: {'warehouse_id': ?warehouseId},
    );
    final items = response.data!['data'] as List<dynamic>;
    return items.cast<Map<String, dynamic>>().map(_stockLevelFromJson).toList();
  }

  StockLevel _stockLevelFromJson(Map<String, dynamic> data) => StockLevel(
    warehouseId: data['warehouse_id'] as String?,
    productId: data['product_id'] as String,
    productVariantId: data['product_variant_id'] as String,
    sku: data['sku'] as String,
    productName: data['product_name'] as String,
    variantName: data['variant_name'] as String?,
    lowStockThreshold: data['low_stock_threshold'] as int?,
    quantity: data['quantity'] as int,
    isLowStock: data['is_low_stock'] as bool,
  );

  Future<StockTransaction> stockIn(StockInParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/inventory/stock-in',
      data: {
        'warehouse_id': params.warehouseId,
        'product_variant_id': params.productVariantId,
        'quantity': params.quantity,
        'reason': params.reason,
        'note': params.note,
      },
    );
    return _transactionFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<StockTransaction> stockOut(StockOutParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/inventory/stock-out',
      data: {
        'warehouse_id': params.warehouseId,
        'product_variant_id': params.productVariantId,
        'quantity': params.quantity,
        'reason': params.reason,
        'note': params.note,
      },
    );
    return _transactionFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<StockTransaction> adjust(AdjustmentParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/inventory/adjustments',
      data: {
        'warehouse_id': params.warehouseId,
        'product_variant_id': params.productVariantId,
        'counted_quantity': params.countedQuantity,
        'reason': params.reason,
        'note': params.note,
      },
    );
    return _transactionFromJson(response.data!['data'] as Map<String, dynamic>);
  }

  StockTransaction _transactionFromJson(Map<String, dynamic> data) =>
      StockTransaction(
        id: data['id'] as String,
        companyId: data['company_id'] as String,
        branchId: data['branch_id'] as String,
        warehouseId: data['warehouse_id'] as String,
        productVariantId: data['product_variant_id'] as String,
        movementType: MovementType.fromWire(data['movement_type'] as String),
        quantityDelta: data['quantity_delta'] as int,
        quantityAfter: data['quantity_after'] as int,
        reason: data['reason'] as String?,
        note: data['note'] as String?,
        transferId: data['transfer_id'] as String?,
        createdAt: DateTime.parse(data['created_at'] as String),
      );

  Future<StockTransfer> transfer(TransferParams params) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/inventory/transfers',
      data: {
        'from_warehouse_id': params.fromWarehouseId,
        'to_warehouse_id': params.toWarehouseId,
        'product_variant_id': params.productVariantId,
        'quantity': params.quantity,
        'note': params.note,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return StockTransfer(
      id: data['id'] as String,
      companyId: data['company_id'] as String,
      fromWarehouseId: data['from_warehouse_id'] as String,
      toWarehouseId: data['to_warehouse_id'] as String,
      productVariantId: data['product_variant_id'] as String,
      quantity: data['quantity'] as int,
      note: data['note'] as String?,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }

  Future<TransactionPage> listTransactions({
    String? warehouseId,
    String? productVariantId,
    MovementType? movementType,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? cursor,
    int limit = 25,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/inventory/transactions',
      queryParameters: {
        'warehouse_id': ?warehouseId,
        'product_variant_id': ?productVariantId,
        'movement_type': ?movementType?.wireValue,
        'date_from': ?dateFrom?.toIso8601String(),
        'date_to': ?dateTo?.toIso8601String(),
        'cursor': ?cursor,
        'limit': limit,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_transactionFromJson)
        .toList();
    return TransactionPage(
      items: items,
      nextCursor: data['next_cursor'] as String?,
      hasMore: data['has_more'] as bool,
    );
  }
}
