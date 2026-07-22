import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_x.dart';
import '../../domain/entities/brand.dart';
import '../../domain/repositories/products_catalog_repository.dart';
import '../providers/products_catalog_providers.dart';

Future<bool?> showBrandFormDialog(BuildContext context, {Brand? existing}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _BrandFormDialog(existing: existing),
  );
}

class _BrandFormDialog extends ConsumerStatefulWidget {
  const _BrandFormDialog({this.existing});

  final Brand? existing;

  @override
  ConsumerState<_BrandFormDialog> createState() => _BrandFormDialogState();
}

class _BrandFormDialogState extends ConsumerState<_BrandFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _logoUrlController;
  late final TextEditingController _descriptionController;
  bool _isActive = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _logoUrlController = TextEditingController(text: existing?.logoUrl ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _logoUrlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final notifier = ref.read(brandsProvider.notifier);
    final existing = widget.existing;

    final result = existing == null
        ? await notifier.create(
            BrandCreateParams(
              name: _nameController.text.trim(),
              logoUrl: _emptyToNull(_logoUrlController.text),
              description: _emptyToNull(_descriptionController.text),
            ),
          )
        : await notifier.updateBrand(
            existing.id,
            BrandUpdateParams(
              name: _nameController.text.trim(),
              logoUrl: _emptyToNull(_logoUrlController.text),
              description: _emptyToNull(_descriptionController.text),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit brand' : 'New brand'),
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
                TextFormField(
                  controller: _logoUrlController,
                  decoration: const InputDecoration(labelText: 'Logo URL'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
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
