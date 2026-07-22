import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/category.dart';
import '../providers/products_catalog_providers.dart';
import '../widgets/category_form_dialog.dart';

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: PermissionGate(
        permission: 'categories.create',
        child: FloatingActionButton.extended(
          onPressed: () => _openCreateDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('New category'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(categoriesProvider),
        child: AsyncValueView(
          value: categoriesAsync,
          onRetry: () => ref.invalidate(categoriesProvider),
          errorPrefix: 'Could not load categories',
          data: (context, categories) {
            if (categories.isEmpty) {
              return ListView(
                children: [
                  const EmptyState(
                    icon: Icons.category_outlined,
                    title: 'No categories yet',
                    message:
                        'Create a category to start organizing your products.',
                  ),
                ],
              );
            }
            final byId = {for (final c in categories) c.id: c};
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final category = categories[index];
                final parentName = category.parentCategoryId != null
                    ? byId[category.parentCategoryId]?.name
                    : null;
                return ListTile(
                  leading: Icon(
                    Icons.category,
                    color: category.isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  title: Text(category.name),
                  subtitle: Text(
                    [
                      if (parentName != null) 'Under $parentName',
                      if (!category.isActive) 'Inactive',
                    ].join(' · '),
                  ),
                  trailing: PermissionGate(
                    permission: 'categories.update',
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit',
                      onPressed: () =>
                          _openEditDialog(context, ref, category, categories),
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

  Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
    final categories = switch (ref.read(categoriesProvider)) {
      AsyncData(:final value) => value,
      _ => const <Category>[],
    };
    final created = await showCategoryFormDialog(
      context,
      allCategories: categories,
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category created')));
    }
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    Category category,
    List<Category> allCategories,
  ) async {
    final saved = await showCategoryFormDialog(
      context,
      existing: category,
      allCategories: allCategories,
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category updated')));
    }
  }
}
