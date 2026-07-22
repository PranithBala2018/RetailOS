import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/movement_type.dart';
import '../../domain/entities/stock_transaction.dart';
import '../providers/inventory_providers.dart';
import '../widgets/warehouse_selector_dropdown.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(transactionHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction history'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: WarehouseSelectorDropdown(),
          ),
        ],
      ),
      body: AsyncValueView(
        value: historyAsync,
        onRetry: () => ref.invalidate(transactionHistoryProvider),
        errorPrefix: 'Could not load transaction history',
        data: (context, state) {
          if (state.items.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No movements yet',
              message:
                  'Stock in, stock out, transfers, and adjustments will show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.items.length + 1,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == state.items.length) {
                if (!state.hasMore) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: state.isLoadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: () => ref
                                .read(transactionHistoryProvider.notifier)
                                .loadMore(),
                            child: const Text('Load more'),
                          ),
                  ),
                );
              }
              return _TransactionTile(transaction: state.items[index]);
            },
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final StockTransaction transaction;

  static final _dateFormat = DateFormat.yMMMd().add_jm();

  @override
  Widget build(BuildContext context) {
    final isPositive = transaction.quantityDelta >= 0;
    final (icon, color) = switch (transaction.movementType) {
      MovementType.stockIn => (Icons.add_box_outlined, Colors.green),
      MovementType.stockOut => (
        Icons.indeterminate_check_box_outlined,
        Colors.orange,
      ),
      MovementType.transferIn => (Icons.call_received, Colors.blue),
      MovementType.transferOut => (Icons.call_made, Colors.blue),
      MovementType.adjustment => (Icons.fact_check_outlined, Colors.purple),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(transaction.movementType.label),
      subtitle: Text(
        [
          _dateFormat.format(transaction.createdAt.toLocal()),
          if (transaction.reason != null) transaction.reason!,
        ].join(' · '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isPositive ? '+' : ''}${transaction.quantityDelta}',
            style: TextStyle(
              color: isPositive
                  ? Colors.green
                  : Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Balance: ${transaction.quantityAfter}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
