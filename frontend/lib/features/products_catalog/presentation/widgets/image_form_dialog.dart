import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_x.dart';
import '../../domain/repositories/products_catalog_repository.dart';
import '../providers/products_catalog_providers.dart';

/// Adds an image by URL — the backend's `product_images` table stores a
/// URL string only (no raw upload endpoint exists yet), so this is a
/// paste-a-link form rather than a file picker.
Future<bool?> showImageFormDialog(
  BuildContext context, {
  required String productId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ImageFormDialog(productId: productId),
  );
}

class _ImageFormDialog extends ConsumerStatefulWidget {
  const _ImageFormDialog({required this.productId});

  final String productId;

  @override
  ConsumerState<_ImageFormDialog> createState() => _ImageFormDialogState();
}

class _ImageFormDialogState extends ConsumerState<_ImageFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _imageUrlController = TextEditingController();
  bool _isPrimary = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final repository = ref.read(productsCatalogRepositoryProvider);
    final result = await repository.addImage(
      widget.productId,
      ProductImageCreateParams(
        imageUrl: _imageUrlController.text.trim(),
        isPrimary: _isPrimary,
      ),
    );

    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _isSubmitting = false;
        _errorMessage = failure.userMessage;
      }),
      (_) {
        ref.invalidate(productImagesProvider(widget.productId));
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add image'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'Image URL *'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Image URL is required'
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Primary image'),
                value: _isPrimary,
                onChanged: (value) => setState(() => _isPrimary = value),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
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
              : const Text('Add'),
        ),
      ],
    );
  }
}
