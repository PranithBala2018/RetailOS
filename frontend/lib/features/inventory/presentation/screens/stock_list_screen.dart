import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/stock_level.dart';
import '../providers/inventory_providers.dart';
import '../widgets/adjustment_form_dialog.dart';
import '../widgets/stock_movement_dialog.dart';
import '../widgets/transfer_form_dialog.dart';
import '../widgets/warehouse_selector_dropdown.dart';

/// Row-first navigation model: every movement dialog opens already
/// knowing which variant it's acting on (the row the user tapped), so
/// there's no separate "pick a product from scratch" flow — matches how
/// small-retail stock screens (Tally/Zoho-style) are typically used:
/// browse the list, act on a row, not fill out a blank form.
class StockListScreen extends ConsumerStatefulWidget {
  const StockListScreen({super.key});

  @override
  ConsumerState<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends ConsumerState<StockListScreen> {
  final _searchController = TextEditingController();
  bool _lowStockOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    ref
        .read(stockListProvider.notifier)
        .applyFilter(
          search: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          lowStockOnly: _lowStockOnly,
        );
  }

  String _productLabel(StockLevel level) => level.variantName != null
      ? '${level.productName} — ${level.variantName}'
      : level.productName;

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(stockListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: WarehouseSelectorDropdown(),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Transaction history',
            onPressed: () => context.push('/inventory/transactions'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _onFilterChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Search by name or SKU',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                FilterChip(
                  label: const Text('Low stock only'),
                  selected: _lowStockOnly,
                  onSelected: (value) {
                    setState(() => _lowStockOnly = value);
                    _onFilterChanged();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(stockListProvider.notifier).refresh(),
              child: AsyncValueView(
                value: stockAsync,
                onRetry: () => ref.read(stockListProvider.notifier).refresh(),
                errorPrefix: 'Could not load stock',
                data: (context, levels) {
                  if (levels.isEmpty) {
                    return ListView(
                      children: const [
                        EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No stock records found',
                          message: 'Record a Stock In to get started.',
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    itemCount: levels.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) => _StockLevelTile(
                      level: levels[index],
                      productLabel: _productLabel(levels[index]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockLevelTile extends ConsumerWidget {
  const _StockLevelTile({required this.level, required this.productLabel});

  final StockLevel level;
  final String productLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouseId = ref.watch(currentWarehouseIdProvider);
    final user = switch (ref.watch(sessionProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };

    final menuItems = <PopupMenuEntry<String>>[
      if (user?.can('inventory.stock_in') ?? false)
        const PopupMenuItem(value: 'stock_in', child: Text('Stock in')),
      if (user?.can('inventory.stock_out') ?? false)
        const PopupMenuItem(value: 'stock_out', child: Text('Stock out')),
      if (user?.can('inventory.transfer') ?? false)
        const PopupMenuItem(value: 'transfer', child: Text('Transfer')),
      if (user?.can('inventory.adjust') ?? false)
        const PopupMenuItem(value: 'adjust', child: Text('Adjust (recount)')),
    ];

    return ListTile(
      leading: Icon(
        level.isLowStock ? Icons.warning_amber : Icons.inventory_2_outlined,
        color: level.isLowStock ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(productLabel),
      subtitle: Text(
        [
          'SKU ${level.sku}',
          if (level.lowStockThreshold != null)
            'Threshold ${level.lowStockThreshold}',
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${level.quantity}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: level.isLowStock
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
          if (menuItems.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (action) =>
                  _handleAction(context, action, warehouseId),
              itemBuilder: (context) => menuItems,
            ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    String? warehouseId,
  ) async {
    switch (action) {
      case 'stock_in':
        await showStockInDialog(
          context,
          productVariantId: level.productVariantId,
          productLabel: productLabel,
          initialWarehouseId: warehouseId,
        );
      case 'stock_out':
        await showStockOutDialog(
          context,
          productVariantId: level.productVariantId,
          productLabel: productLabel,
          initialWarehouseId: warehouseId,
        );
      case 'transfer':
        await showTransferFormDialog(
          context,
          productVariantId: level.productVariantId,
          productLabel: productLabel,
          initialFromWarehouseId: warehouseId,
        );
      case 'adjust':
        await showAdjustmentFormDialog(
          context,
          productVariantId: level.productVariantId,
          productLabel: productLabel,
          currentQuantity: level.quantity,
          initialWarehouseId: warehouseId,
        );
    }
  }
}
