import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_x.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/products_catalog_repository.dart';
import '../providers/products_catalog_providers.dart';

/// Create/edit dialog for a [Category]. Pass [existing] to edit in place
/// (pre-fills every field and calls `updateCategory`); omit it to create
/// a new one. Returns `true` via `Navigator.pop` on success so the
/// caller can show a snackbar, matching the rest of this module's dialogs.
Future<bool?> showCategoryFormDialog(
  BuildContext context, {
  Category? existing,
  required List<Category> allCategories,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) =>
        _CategoryFormDialog(existing: existing, allCategories: allCategories),
  );
}

class _CategoryFormDialog extends ConsumerStatefulWidget {
  const _CategoryFormDialog({this.existing, required this.allCategories});

  final Category? existing;
  final List<Category> allCategories;

  @override
  ConsumerState<_CategoryFormDialog> createState() =>
      _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _displayOrderController;
  String? _parentCategoryId;
  bool _isActive = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _imageUrlController = TextEditingController(text: existing?.imageUrl ?? '');
    _displayOrderController = TextEditingController(
      text: (existing?.displayOrder ?? 0).toString(),
    );
    _parentCategoryId = existing?.parentCategoryId;
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final displayOrder = int.tryParse(_displayOrderController.text.trim()) ?? 0;
    final notifier = ref.read(categoriesProvider.notifier);
    final existing = widget.existing;

    final result = existing == null
        ? await notifier.create(
            CategoryCreateParams(
              name: _nameController.text.trim(),
              parentCategoryId: _parentCategoryId,
              description: _emptyToNull(_descriptionController.text),
              imageUrl: _emptyToNull(_imageUrlController.text),
              displayOrder: displayOrder,
            ),
          )
        : await notifier.updateCategory(
            existing.id,
            CategoryUpdateParams(
              name: _nameController.text.trim(),
              parentCategoryId: _parentCategoryId,
              description: _emptyToNull(_descriptionController.text),
              imageUrl: _emptyToNull(_imageUrlController.text),
              displayOrder: displayOrder,
              isActive: _isActive,
            ),
            existing.version,
          );

    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _isSubmitting = false;
        _errorMessage = failure.userMessage;
      }),
      (_) => Navigator.of(context).pop(true),
    );
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    final parentOptions = widget.allCategories
        .where((c) => c.id != widget.existing?.id)
        .toList();

    return AlertDialog(
      title: Text(_isEditing ? 'Edit category' : 'New category'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _parentCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Parent category',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None'),
                    ),
                    ...parentOptions.map(
                      (c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _parentCategoryId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _displayOrderController,
                  decoration: const InputDecoration(labelText: 'Display order'),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      int.tryParse(value?.trim() ?? '') == null
                      ? 'Must be a whole number'
                      : null,
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
