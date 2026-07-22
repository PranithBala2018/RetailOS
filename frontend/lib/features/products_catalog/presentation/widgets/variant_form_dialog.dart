import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_x.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/repositories/products_catalog_repository.dart';
import '../providers/products_catalog_providers.dart';

/// Add a new variant to [productId], or edit an [existing] one in place.
Future<bool?> showVariantFormDialog(
  BuildContext context, {
  required String productId,
  ProductVariant? existing,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) =>
        _VariantFormDialog(productId: productId, existing: existing),
  );
}

class _VariantFormDialog extends ConsumerStatefulWidget {
  const _VariantFormDialog({required this.productId, this.existing});

  final String productId;
  final ProductVariant? existing;

  @override
  ConsumerState<_VariantFormDialog> createState() => _VariantFormDialogState();
}

class _VariantFormDialogState extends ConsumerState<_VariantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _skuController;
  late final TextEditingController _sizeController;
  late final TextEditingController _colorController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _mrpController;
  bool _isActive = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _skuController = TextEditingController(text: existing?.sku ?? '');
    _sizeController = TextEditingController(text: existing?.size ?? '');
    _colorController = TextEditingController(text: existing?.color ?? '');
    _purchasePriceController = TextEditingController(
      text: existing?.purchasePrice ?? '0',
    );
    _sellingPriceController = TextEditingController(
      text: existing?.sellingPrice ?? '0',
    );
    _mrpController = TextEditingController(text: existing?.mrp ?? '');
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _skuController.dispose();
    _sizeController.dispose();
    _colorController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _mrpController.dispose();
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

    final notifier = ref.read(productDetailProvider(widget.productId).notifier);
    final existing = widget.existing;

    final result = existing == null
        ? await notifier.addVariant(
            ProductVariantInputParams(
              sku: _skuController.text.trim(),
              size: _emptyToNull(_sizeController.text),
              color: _emptyToNull(_colorController.text),
              purchasePrice:
                  MoneyFormat.parseToWire(_purchasePriceController.text) ?? '0',
              sellingPrice:
                  MoneyFormat.parseToWire(_sellingPriceController.text) ?? '0',
              mrp: MoneyFormat.parseToWire(_mrpController.text),
            ),
          )
        : await notifier.updateVariant(
            existing.id,
            ProductVariantUpdateParams(
              size: _emptyToNull(_sizeController.text),
              color: _emptyToNull(_colorController.text),
              purchasePrice:
                  MoneyFormat.parseToWire(_purchasePriceController.text) ?? '0',
              sellingPrice:
                  MoneyFormat.parseToWire(_sellingPriceController.text) ?? '0',
              mrp: MoneyFormat.parseToWire(_mrpController.text),
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
      title: Text(_isEditing ? 'Edit variant' : 'Add variant'),
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
                  controller: _skuController,
                  enabled: !_isEditing,
                  decoration: const InputDecoration(labelText: 'Variant SKU *'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'SKU is required'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _sizeController,
                        decoration: const InputDecoration(labelText: 'Size'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        decoration: const InputDecoration(labelText: 'Color'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _purchasePriceController,
                  decoration: const InputDecoration(
                    labelText: 'Purchase price',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => MoneyFormat.isValid(value ?? '')
                      ? null
                      : 'Invalid amount',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sellingPriceController,
                  decoration: const InputDecoration(labelText: 'Selling price'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => MoneyFormat.isValid(value ?? '')
                      ? null
                      : 'Invalid amount',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mrpController,
                  decoration: const InputDecoration(labelText: 'MRP'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) =>
                      (value != null &&
                          value.trim().isNotEmpty &&
                          !MoneyFormat.isValid(value))
                      ? 'Invalid amount'
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
              : Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
