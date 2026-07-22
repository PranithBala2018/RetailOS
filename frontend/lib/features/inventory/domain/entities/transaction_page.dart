import 'package:freezed_annotation/freezed_annotation.dart';

import 'stock_transaction.dart';

part 'transaction_page.freezed.dart';

/// Mirrors the backend's `Page[T]` (app/common/pagination.py) — the
/// first cursor-paginated response shape on either side of this app.
@freezed
abstract class TransactionPage with _$TransactionPage {
  const factory TransactionPage({
    required List<StockTransaction> items,
    String? nextCursor,
    required bool hasMore,
  }) = _TransactionPage;
}
