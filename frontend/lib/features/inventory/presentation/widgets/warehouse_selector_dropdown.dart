import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inventory_providers.dart';

/// App-bar-style dropdown backing the shared `currentWarehouseIdProvider`
/// — chosen once, respected by every Inventory screen. `null` reads as
/// "All warehouses".
class WarehouseSelectorDropdown extends ConsumerWidget {
  const WarehouseSelectorDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehousesAsync = ref.watch(warehousesProvider);
    final currentWarehouseId = ref.watch(currentWarehouseIdProvider);

    return warehousesAsync.when(
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, _) => const Icon(Icons.error_outline),
      data: (warehouses) => DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: currentWarehouseId,
          icon: const Icon(Icons.arrow_drop_down),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All warehouses'),
            ),
            ...warehouses.map(
              (w) =>
                  DropdownMenuItem<String?>(value: w.id, child: Text(w.name)),
            ),
          ],
          onChanged: (value) =>
              ref.read(currentWarehouseIdProvider.notifier).select(value),
        ),
      ),
    );
  }
}
