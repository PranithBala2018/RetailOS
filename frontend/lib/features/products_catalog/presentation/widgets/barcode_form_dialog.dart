import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_x.dart';
import '../../domain/entities/barcode_type.dart';
import '../../domain/repositories/products_catalog_repository.dart';
import '../providers/products_catalog_providers.dart';

Future<bool?> showBarcodeFormDialog(
  BuildContext context, {
  required String variantId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _BarcodeFormDialog(variantId: variantId),
  );
}

class _BarcodeFormDialog extends ConsumerStatefulWidget {
  const _BarcodeFormDialog({required this.variantId});

  final String variantId;

  @override
  ConsumerState<_BarcodeFormDialog> createState() => _BarcodeFormDialogState();
}

class _BarcodeFormDialogState extends ConsumerState<_BarcodeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  BarcodeType _barcodeType = BarcodeType.internal;
  bool _isPrimary = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final repository = ref.read(productsCatalogRepositoryProvider);
    final result = await repository.addBarcode(
      widget.variantId,
      ProductBarcodeCreateParams(
        barcode: _barcodeController.text.trim(),
        barcodeType: _barcodeType,
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
        ref.invalidate(variantBarcodesProvider(widget.variantId));
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add barcode'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(labelText: 'Barcode *'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Barcode is required'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<BarcodeType>(
                initialValue: _barcodeType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: BarcodeType.values
                    .map(
                      (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                    )
                    .toList(),
                onChanged: (value) => setState(
                  () => _barcodeType = value ?? BarcodeType.internal,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Primary barcode'),
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
