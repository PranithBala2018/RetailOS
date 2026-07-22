import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/features/inventory/data/datasources/inventory_remote_data_source.dart';
import 'package:retailos/features/inventory/domain/entities/movement_type.dart';
import 'package:retailos/features/inventory/domain/repositories/inventory_repository.dart';

void main() {
  late HttpServer server;
  late Dio dio;
  late InventoryRemoteDataSource dataSource;
  Uri? lastRequestUri;
  Map<String, dynamic>? lastRequestBody;

  Future<void> respond(HttpRequest request, Object body) async {
    lastRequestUri = request.uri;
    if (request.method != 'GET') {
      final raw = await utf8.decoder.bind(request).join();
      lastRequestBody = raw.isEmpty
          ? null
          : jsonDecode(raw) as Map<String, dynamic>;
    }
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dio = Dio(
      BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'),
    );
    dataSource = InventoryRemoteDataSource(dio);
    lastRequestUri = null;
    lastRequestBody = null;
  });

  tearDown(() async {
    await server.close(force: true);
    dio.close();
  });

  test('listWarehouses parses every field', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'ok',
        'data': [
          {
            'id': 'wh-1',
            'company_id': 'company-1',
            'branch_id': 'branch-1',
            'name': 'Main Warehouse',
            'code': 'MAIN',
            'is_default': true,
            'is_active': true,
          },
        ],
      }),
    );

    final warehouses = await dataSource.listWarehouses();

    expect(warehouses.single.name, 'Main Warehouse');
    expect(warehouses.single.isDefault, isTrue);
  });

  test(
    'listStock sends warehouse_id, search, and low_stock_only as query parameters',
    () async {
      server.listen(
        (request) => respond(request, {
          'success': true,
          'message': 'ok',
          'data': <dynamic>[],
        }),
      );

      await dataSource.listStock(
        warehouseId: 'wh-1',
        search: 'tea',
        lowStockOnly: true,
      );

      expect(lastRequestUri!.queryParameters['warehouse_id'], 'wh-1');
      expect(lastRequestUri!.queryParameters['search'], 'tea');
      expect(lastRequestUri!.queryParameters['low_stock_only'], 'true');
    },
  );

  test('listStock parses a stock level including is_low_stock', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'ok',
        'data': [
          {
            'warehouse_id': 'wh-1',
            'product_id': 'prod-1',
            'product_variant_id': 'var-1',
            'sku': 'TEA-001',
            'product_name': 'Masala Tea',
            'variant_name': null,
            'low_stock_threshold': 5,
            'quantity': 2,
            'is_low_stock': true,
          },
        ],
      }),
    );

    final levels = await dataSource.listStock();

    expect(levels.single.sku, 'TEA-001');
    expect(levels.single.isLowStock, isTrue);
  });

  test('stockIn posts the expected body and parses the transaction', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'Stock in recorded',
        'data': {
          'id': 'txn-1',
          'company_id': 'company-1',
          'branch_id': 'branch-1',
          'warehouse_id': 'wh-1',
          'product_variant_id': 'var-1',
          'movement_type': 'stock_in',
          'quantity_delta': 10,
          'quantity_after': 10,
          'reason': 'Opening stock',
          'note': null,
          'transfer_id': null,
          'created_at': '2026-07-22T10:00:00Z',
        },
      }),
    );

    final transaction = await dataSource.stockIn(
      const StockInParams(
        warehouseId: 'wh-1',
        productVariantId: 'var-1',
        quantity: 10,
        reason: 'Opening stock',
      ),
    );

    expect(lastRequestBody!['quantity'], 10);
    expect(lastRequestBody!['reason'], 'Opening stock');
    expect(transaction.movementType, MovementType.stockIn);
    expect(transaction.quantityAfter, 10);
  });

  test('adjust posts counted_quantity, not a delta', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'Adjustment recorded',
        'data': {
          'id': 'txn-2',
          'company_id': 'company-1',
          'branch_id': 'branch-1',
          'warehouse_id': 'wh-1',
          'product_variant_id': 'var-1',
          'movement_type': 'adjustment',
          'quantity_delta': -3,
          'quantity_after': 7,
          'reason': 'recount',
          'note': null,
          'transfer_id': null,
          'created_at': '2026-07-22T10:05:00Z',
        },
      }),
    );

    final transaction = await dataSource.adjust(
      const AdjustmentParams(
        warehouseId: 'wh-1',
        productVariantId: 'var-1',
        countedQuantity: 7,
        reason: 'recount',
      ),
    );

    expect(lastRequestBody!['counted_quantity'], 7);
    expect(lastRequestBody!.containsKey('quantity_delta'), isFalse);
    expect(transaction.quantityDelta, -3);
  });

  test('transfer posts both warehouse ids and parses the transfer', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'Transfer recorded',
        'data': {
          'id': 'transfer-1',
          'company_id': 'company-1',
          'from_warehouse_id': 'wh-1',
          'to_warehouse_id': 'wh-2',
          'product_variant_id': 'var-1',
          'quantity': 4,
          'note': null,
          'created_at': '2026-07-22T10:10:00Z',
        },
      }),
    );

    final transfer = await dataSource.transfer(
      const TransferParams(
        fromWarehouseId: 'wh-1',
        toWarehouseId: 'wh-2',
        productVariantId: 'var-1',
        quantity: 4,
      ),
    );

    expect(lastRequestBody!['from_warehouse_id'], 'wh-1');
    expect(lastRequestBody!['to_warehouse_id'], 'wh-2');
    expect(transfer.quantity, 4);
  });

  test('listTransactions parses a paginated response', () async {
    server.listen(
      (request) => respond(request, {
        'success': true,
        'message': 'ok',
        'data': {
          'items': [
            {
              'id': 'txn-1',
              'company_id': 'company-1',
              'branch_id': 'branch-1',
              'warehouse_id': 'wh-1',
              'product_variant_id': 'var-1',
              'movement_type': 'stock_out',
              'quantity_delta': -2,
              'quantity_after': 8,
              'reason': null,
              'note': null,
              'transfer_id': null,
              'created_at': '2026-07-22T10:15:00Z',
            },
          ],
          'next_cursor': 'abc123',
          'has_more': true,
        },
      }),
    );

    final page = await dataSource.listTransactions(limit: 1);

    expect(lastRequestUri!.queryParameters['limit'], '1');
    expect(page.items.single.movementType, MovementType.stockOut);
    expect(page.nextCursor, 'abc123');
    expect(page.hasMore, isTrue);
  });
}
