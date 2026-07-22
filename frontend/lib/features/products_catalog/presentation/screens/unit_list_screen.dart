import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../providers/products_catalog_providers.dart';
import '../widgets/unit_form_dialog.dart';

class UnitListScreen extends ConsumerWidget {
  const UnitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Units of measure')),
      floatingActionButton: PermissionGate(
        permission: 'units.create',
        child: FloatingActionButton.extended(
          onPressed: () => _openCreateDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('New unit'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(unitsProvider),
        child: AsyncValueView(
          value: unitsAsync,
          onRetry: () => ref.invalidate(unitsProvider),
          errorPrefix: 'Could not load units',
          data: (context, units) {
            if (units.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(
                    icon: Icons.straighten_outlined,
                    title: 'No units yet',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: units.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final unit = units[index];
                return ListTile(
                  leading: const Icon(Icons.straighten),
                  title: Text('${unit.name} (${unit.abbreviation})'),
                  trailing: unit.isSystem
                      ? Chip(
                          label: const Text('System'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        )
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final created = await showUnitFormDialog(context);
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unit created')));
    }
  }
}
