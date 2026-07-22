import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/brand.dart';
import '../providers/products_catalog_providers.dart';
import '../widgets/brand_form_dialog.dart';

class BrandListScreen extends ConsumerWidget {
  const BrandListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.watch(brandsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Brands')),
      floatingActionButton: PermissionGate(
        permission: 'brands.create',
        child: FloatingActionButton.extended(
          onPressed: () => _openCreateDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('New brand'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(brandsProvider),
        child: AsyncValueView(
          value: brandsAsync,
          onRetry: () => ref.invalidate(brandsProvider),
          errorPrefix: 'Could not load brands',
          data: (context, brands) {
            if (brands.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(
                    icon: Icons.sell_outlined,
                    title: 'No brands yet',
                    message: 'Create a brand to tag your products with.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: brands.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final brand = brands[index];
                return ListTile(
                  leading: Icon(
                    Icons.sell,
                    color: brand.isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  title: Text(brand.name),
                  subtitle: brand.isActive ? null : const Text('Inactive'),
                  trailing: PermissionGate(
                    permission: 'brands.update',
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit',
                      onPressed: () => _openEditDialog(context, brand),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final created = await showBrandFormDialog(context);
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Brand created')));
    }
  }

  Future<void> _openEditDialog(BuildContext context, Brand brand) async {
    final saved = await showBrandFormDialog(context, existing: brand);
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Brand updated')));
    }
  }
}
