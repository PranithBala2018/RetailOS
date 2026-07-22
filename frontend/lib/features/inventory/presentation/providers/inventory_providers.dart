import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/failure.dart';
import '../../data/datasources/inventory_remote_data_source.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/entities/movement_type.dart';
import '../../domain/entities/stock_level.dart';
import '../../domain/entities/stock_transaction.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/repositories/inventory_repository.dart';

part 'inventory_providers.g.dart';

@riverpod
InventoryRepository inventoryRepository(Ref ref) {
  return InventoryRepositoryImpl(
    InventoryRemoteDataSource(ref.watch(dioProvider)),
  );
}

@riverpod
class WarehousesNotifier extends _$WarehousesNotifier {
  @override
  Future<List<Warehouse>> build() async {
    final result = await ref
        .watch(inventoryRepositoryProvider)
        .listWarehouses();
    return result.match((failure) => throw failure, (warehouses) => warehouses);
  }
}

/// The currently-selected warehouse for every Inventory screen —
/// `null` means "All warehouses" (an aggregate view; see
/// `InventoryService.list_stock`'s summing behavior on the backend when
/// no `warehouse_id` is given). Plain synchronous state, not `@riverpod`
/// async, since it never fetches anything itself — it just holds a
/// selection sourced from `warehousesProvider`. Feature-scoped rather
/// than session-wide, since warehouse (unlike branch) isn't a JWT claim.
@riverpod
class CurrentWarehouseId extends _$CurrentWarehouseId {
  @override
  String? build() => null;

  void select(String? warehouseId) => state = warehouseId;
}

/// Owns the stock list and its active search/category/low-stock filter,
/// so mutations can re-fetch with the filter still applied — mirrors
/// `products_catalog`'s `ProductListNotifier`.
@riverpod
class StockListNotifier extends _$StockListNotifier {
  String? _search;
  String? _categoryId;
  bool _lowStockOnly = false;

  @override
  Future<List<StockLevel>> build() async {
    final warehouseId = ref.watch(currentWarehouseIdProvider);
    final result = await ref
        .watch(inventoryRepositoryProvider)
        .listStock(
          warehouseId: warehouseId,
          search: _search,
          categoryId: _categoryId,
          lowStockOnly: _lowStockOnly,
        );
    return result.match((failure) => throw failure, (levels) => levels);
  }

  Future<void> applyFilter({
    String? search,
    String? categoryId,
    bool lowStockOnly = false,
  }) async {
    _search = search;
    _categoryId = categoryId;
    _lowStockOnly = lowStockOnly;
    ref.invalidateSelf();
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<Either<Failure, StockTransaction>> stockIn(
    StockInParams params,
  ) async {
    final result = await ref.read(inventoryRepositoryProvider).stockIn(params);
    if (result.isRight()) await refresh();
    return result;
  }

  Future<Either<Failure, StockTransaction>> stockOut(
    StockOutParams params,
  ) async {
    final result = await ref.read(inventoryRepositoryProvider).stockOut(params);
    if (result.isRight()) await refresh();
    return result;
  }

  Future<Either<Failure, StockTransaction>> adjust(
    AdjustmentParams params,
  ) async {
    final result = await ref.read(inventoryRepositoryProvider).adjust(params);
    if (result.isRight()) await refresh();
    return result;
  }

  Future<Either<Failure, StockTransfer>> transfer(TransferParams params) async {
    final result = await ref.read(inventoryRepositoryProvider).transfer(params);
    if (result.isRight()) await refresh();
    return result;
  }
}

class TransactionHistoryState {
  const TransactionHistoryState({
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<StockTransaction> items;
  final bool hasMore;
  final bool isLoadingMore;

  TransactionHistoryState copyWith({
    List<StockTransaction>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) => TransactionHistoryState(
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

/// The first Flutter screen backed by real cursor pagination (every
/// other list in this app fetches everything and paginates client-side
/// — see `products_catalog`'s known-issue note). Accumulates pages into
/// one growing list via `loadMore()`, "load more" style rather than a
/// page-by-page view, since a scrolling ledger reads more naturally that
/// way than a paged table.
@riverpod
class TransactionHistoryNotifier extends _$TransactionHistoryNotifier {
  String? _cursor;
  String? _productVariantId;
  MovementType? _movementType;

  @override
  Future<TransactionHistoryState> build() async {
    final warehouseId = ref.watch(currentWarehouseIdProvider);
    _cursor = null;
    final result = await ref
        .watch(inventoryRepositoryProvider)
        .listTransactions(
          warehouseId: warehouseId,
          productVariantId: _productVariantId,
          movementType: _movementType,
        );
    return result.match((failure) => throw failure, (page) {
      _cursor = page.nextCursor;
      return TransactionHistoryState(
        items: page.items,
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    });
  }

  Future<void> applyFilter({
    String? productVariantId,
    MovementType? movementType,
  }) async {
    _productVariantId = productVariantId;
    _movementType = movementType;
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final current = switch (state) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    final warehouseId = ref.read(currentWarehouseIdProvider);
    final result = await ref
        .read(inventoryRepositoryProvider)
        .listTransactions(
          warehouseId: warehouseId,
          productVariantId: _productVariantId,
          movementType: _movementType,
          cursor: _cursor,
        );
    result.match(
      (failure) => state = AsyncData(current.copyWith(isLoadingMore: false)),
      (page) {
        _cursor = page.nextCursor;
        state = AsyncData(
          TransactionHistoryState(
            items: [...current.items, ...page.items],
            hasMore: page.hasMore,
            isLoadingMore: false,
          ),
        );
      },
    );
  }
}
