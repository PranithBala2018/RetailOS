import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../../domain/entities/movement_type.dart';
import '../../domain/entities/stock_level.dart';
import '../../domain/entities/stock_transaction.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/entities/transaction_page.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_remote_data_source.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._remoteDataSource);

  final InventoryRemoteDataSource _remoteDataSource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on DioException catch (e) {
      return Left(mapDioException(e));
    } catch (e) {
      return Left(Failure.unexpected(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Warehouse>>> listWarehouses() =>
      _guard(_remoteDataSource.listWarehouses);

  @override
  Future<Either<Failure, List<StockLevel>>> listStock({
    String? warehouseId,
    String? search,
    String? categoryId,
    bool lowStockOnly = false,
  }) => _guard(
    () => _remoteDataSource.listStock(
      warehouseId: warehouseId,
      search: search,
      categoryId: categoryId,
      lowStockOnly: lowStockOnly,
    ),
  );

  @override
  Future<Either<Failure, StockLevel>> getStockLevel(
    String productVariantId, {
    String? warehouseId,
  }) => _guard(
    () => _remoteDataSource.getStockLevel(
      productVariantId,
      warehouseId: warehouseId,
    ),
  );

  @override
  Future<Either<Failure, List<StockLevel>>> listLowStock({
    String? warehouseId,
  }) => _guard(() => _remoteDataSource.listLowStock(warehouseId: warehouseId));

  @override
  Future<Either<Failure, StockTransaction>> stockIn(StockInParams params) =>
      _guard(() => _remoteDataSource.stockIn(params));

  @override
  Future<Either<Failure, StockTransaction>> stockOut(StockOutParams params) =>
      _guard(() => _remoteDataSource.stockOut(params));

  @override
  Future<Either<Failure, StockTransaction>> adjust(AdjustmentParams params) =>
      _guard(() => _remoteDataSource.adjust(params));

  @override
  Future<Either<Failure, StockTransfer>> transfer(TransferParams params) =>
      _guard(() => _remoteDataSource.transfer(params));

  @override
  Future<Either<Failure, TransactionPage>> listTransactions({
    String? warehouseId,
    String? productVariantId,
    MovementType? movementType,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? cursor,
    int limit = 25,
  }) => _guard(
    () => _remoteDataSource.listTransactions(
      warehouseId: warehouseId,
      productVariantId: productVariantId,
      movementType: movementType,
      dateFrom: dateFrom,
      dateTo: dateTo,
      cursor: cursor,
      limit: limit,
    ),
  );
}
