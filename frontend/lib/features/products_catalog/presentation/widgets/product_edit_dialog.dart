import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_x.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_gender.dart';
import '../../domain/repositories/products_catalog_repository.dart';
import '../providers/products_catalog_providers.dart';

/// Edits everything `PUT /products/{id}` can change. Deliberately does
/// not touch `sku`/`hasVariants`/variants — those are fixed at creation
/// (see `ProductCreateScreen`'s docstring) and managed via the variant
/// endpoints from the detail screen instead.
Future<bool?> showProductEditDialog(
  BuildContext context, {
  required Product product,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ProductEditDialog(product: product),
  );
}

class _ProductEditDialog extends ConsumerStatefulWidget {
  const _ProductEditDialog({required this.product});

  final Product product;

  @override
  ConsumerState<_ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends ConsumerState<_ProductEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _hsnCodeController;
  late final TextEditingController _taxPercentController;
  late final TextEditingController _lowStockThresholdController;
  late final TextEditingController _seasonController;
  late final TextEditingController _ageGroupController;
  String? _categoryId;
  String? _brandId;
  ProductGender? _gender;
  late bool _trackInventory;
  late bool _allowNegativeStock;
  late bool _isActive;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product.name);
    _descriptionController = TextEditingController(
      text: product.description ?? '',
    );
    _hsnCodeController = TextEditingController(text: product.hsnCode ?? '');
    _taxPercentController = TextEditingController(
      text: product.taxPercent ?? '',
    );
    _lowStockThresholdController = TextEditingController(
      text: product.lowStockThreshold?.toString() ?? '',
    );
    _seasonController = TextEditingController(text: product.season ?? '');
    _ageGroupController = TextEditingController(text: product.ageGroup ?? '');
    _categoryId = product.categoryId;
    _brandId = product.brandId;
    _gender = product.gender;
    _trackInventory = product.trackInventory;
    _allowNegativeStock = product.allowNegativeStock;
    _isActive = product.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _hsnCodeController.dispose();
    _taxPercentController.dispose();
    _lowStockThresholdController.dispose();
    _seasonController.dispose();
    _ageGroupController.dispose();
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

    final result = await ref
        .read(productDetailProvider(widget.product.id).notifier)
        .updateProduct(
          ProductUpdateParams(
            name: _nameController.text.trim(),
            description: _emptyToNull(_descriptionController.text),
            categoryId: _categoryId,
            brandId: _brandId,
            gender: _gender,
            season: _emptyToNull(_seasonController.text),
            ageGroup: _emptyToNull(_ageGroupController.text),
            hsnCode: _emptyToNull(_hsnCodeController.text),
            taxPercent: MoneyFormat.parseToWire(_taxPercentController.text),
            trackInventory: _trackInventory,
            allowNegativeStock: _allowNegativeStock,
            lowStockThreshold: int.tryParse(
              _lowStockThresholdController.text.trim(),
            ),
            isActive: _isActive,
          ),
          widget.product.version,
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
    final categories = ref
        .watch(categoriesProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <Category>[]);
    final brands = ref
        .watch(brandsProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <Brand>[]);

    return AlertDialog(
      title: const Text('Edit product'),
      content: SizedBox(
        width: 480,
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
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...categories.map(
                            (c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _categoryId = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _brandId,
                        decoration: const InputDecoration(labelText: 'Brand'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...brands.map(
                            (b) => DropdownMenuItem<String?>(
                              value: b.id,
                              child: Text(b.name),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _brandId = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ProductGender?>(
                        initialValue: _gender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: [
                          const DropdownMenuItem<ProductGender?>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...ProductGender.values.map(
                            (g) => DropdownMenuItem<ProductGender?>(
                              value: g,
                              child: Text(g.label),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() => _gender = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _seasonController,
                        decoration: const InputDecoration(labelText: 'Season'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageGroupController,
                        decoration: const InputDecoration(
                          labelText: 'Age group',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _hsnCodeController,
                        decoration: const InputDecoration(
                          labelText: 'HSN code',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _taxPercentController,
                        decoration: const InputDecoration(labelText: 'Tax %'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) =>
                            (value != null &&
                                value.trim().isNotEmpty &&
                                MoneyFormat.parseToWire(value) == null)
                            ? 'Invalid percentage'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lowStockThresholdController,
                        decoration: const InputDecoration(
                          labelText: 'Low stock threshold',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Track inventory'),
                  value: _trackInventory,
                  onChanged: (value) => setState(() => _trackInventory = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow negative stock'),
                  value: _allowNegativeStock,
                  onChanged: (value) =>
                      setState(() => _allowNegativeStock = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
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
              : const Text('Save'),
        ),
      ],
    );
  }
}
