import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retailos/core/error/failure.dart';
import 'package:retailos/features/inventory/data/datasources/inventory_remote_data_source.dart';
import 'package:retailos/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:retailos/features/inventory/domain/entities/movement_type.dart';
import 'package:retailos/features/inventory/domain/entities/stock_transaction.dart';
import 'package:retailos/features/inventory/domain/repositories/inventory_repository.dart';

class _MockInventoryRemoteDataSource extends Mock
    implements InventoryRemoteDataSource {}

void main() {
  late _MockInventoryRemoteDataSource dataSource;
  late InventoryRepositoryImpl repository;

  final transaction = StockTransaction(
    id: 'txn-1',
    companyId: 'company-1',
    branchId: 'branch-1',
    warehouseId: 'wh-1',
    productVariantId: 'var-1',
    movementType: MovementType.stockIn,
    quantityDelta: 10,
    quantityAfter: 10,
    createdAt: DateTime.utc(2026, 7, 22),
  );

  setUpAll(() {
    registerFallbackValue(
      const StockInParams(warehouseId: '', productVariantId: '', quantity: 1),
    );
    registerFallbackValue(
      const StockOutParams(warehouseId: '', productVariantId: '', quantity: 1),
    );
    registerFallbackValue(
      const AdjustmentParams(
        warehouseId: '',
        productVariantId: '',
        countedQuantity: 0,
        reason: '',
      ),
    );
    registerFallbackValue(
      const TransferParams(
        fromWarehouseId: '',
        toWarehouseId: '',
        productVariantId: '',
        quantity: 1,
      ),
    );
  });

  setUp(() {
    dataSource = _MockInventoryRemoteDataSource();
    repository = InventoryRepositoryImpl(dataSource);
  });

  test('stockIn returns the transaction on success', () async {
    when(() => dataSource.stockIn(any())).thenAnswer((_) async => transaction);

    final result = await repository.stockIn(
      const StockInParams(
        warehouseId: 'wh-1',
        productVariantId: 'var-1',
        quantity: 10,
      ),
    );

    expect(result.getRight().toNullable(), transaction);
  });

  test(
    'stockOut maps a 422 (insufficient stock) to Failure.validation',
    () async {
      when(() => dataSource.stockOut(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/inventory/stock-out'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/inventory/stock-out'),
            statusCode: 422,
            data: {
              'success': false,
              'message': 'Insufficient stock',
              'errors': <Object?>[],
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      final result = await repository.stockOut(
        const StockOutParams(
          warehouseId: 'wh-1',
          productVariantId: 'var-1',
          quantity: 100,
        ),
      );

      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
    },
  );

  test('adjust returns the transaction on success', () async {
    when(() => dataSource.adjust(any())).thenAnswer((_) async => transaction);

    final result = await repository.adjust(
      const AdjustmentParams(
        warehouseId: 'wh-1',
        productVariantId: 'var-1',
        countedQuantity: 7,
        reason: 'recount',
      ),
    );

    expect(result.getRight().toNullable(), transaction);
  });

  test('transfer maps a connection error to Failure.network', () async {
    when(() => dataSource.transfer(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/v1/inventory/transfers'),
        type: DioExceptionType.connectionError,
      ),
    );

    final result = await repository.transfer(
      const TransferParams(
        fromWarehouseId: 'wh-1',
        toWarehouseId: 'wh-2',
        productVariantId: 'var-1',
        quantity: 1,
      ),
    );

    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
  });

  test(
    'listWarehouses maps any other thrown error to Failure.unexpected',
    () async {
      when(() => dataSource.listWarehouses()).thenThrow(StateError('boom'));

      final result = await repository.listWarehouses();

      expect(result.getLeft().toNullable(), isA<UnexpectedFailure>());
    },
  );
}
