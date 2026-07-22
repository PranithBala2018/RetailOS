import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_x.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product_gender.dart';
import '../../domain/entities/unit_of_measure.dart';
import '../../domain/repositories/products_catalog_repository.dart';
import '../providers/products_catalog_providers.dart';

/// Full create form, including the variant editor — the one screen that
/// can set `sku`/`hasVariants`/initial variants, since the backend's
/// `PUT /products/{id}` (see `ProductUpdateParams`) never touches those:
/// once a product exists, variants are added one at a time via
/// `POST /products/{id}/variants` from the detail screen instead.
class ProductCreateScreen extends ConsumerStatefulWidget {
  const ProductCreateScreen({super.key});

  @override
  ConsumerState<ProductCreateScreen> createState() =>
      _ProductCreateScreenState();
}

class _VariantRow {
  _VariantRow()
    : skuController = TextEditingController(),
      sizeController = TextEditingController(),
      colorController = TextEditingController(),
      purchasePriceController = TextEditingController(text: '0'),
      sellingPriceController = TextEditingController(text: '0'),
      mrpController = TextEditingController();

  final TextEditingController skuController;
  final TextEditingController sizeController;
  final TextEditingController colorController;
  final TextEditingController purchasePriceController;
  final TextEditingController sellingPriceController;
  final TextEditingController mrpController;

  void dispose() {
    skuController.dispose();
    sizeController.dispose();
    colorController.dispose();
    purchasePriceController.dispose();
    sellingPriceController.dispose();
    mrpController.dispose();
  }
}

class _ProductCreateScreenState extends ConsumerState<ProductCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hsnCodeController = TextEditingController();
  final _taxPercentController = TextEditingController();
  final _lowStockThresholdController = TextEditingController();
  final _purchasePriceController = TextEditingController(text: '0');
  final _sellingPriceController = TextEditingController(text: '0');
  final _mrpController = TextEditingController();

  String? _categoryId;
  String? _brandId;
  String? _baseUnitId;
  ProductGender? _gender;
  final _seasonController = TextEditingController();
  final _ageGroupController = TextEditingController();
  bool _trackInventory = true;
  bool _allowNegativeStock = false;
  bool _hasVariants = false;
  final List<_VariantRow> _variantRows = [];

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _hsnCodeController.dispose();
    _taxPercentController.dispose();
    _lowStockThresholdController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _mrpController.dispose();
    _seasonController.dispose();
    _ageGroupController.dispose();
    for (final row in _variantRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addVariantRow() => setState(() => _variantRows.add(_VariantRow()));

  void _removeVariantRow(int index) =>
      setState(() => _variantRows.removeAt(index).dispose());

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_hasVariants && _variantRows.isEmpty) {
      setState(
        () => _errorMessage =
            'Add at least one variant, or turn off "Has variants".',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final params = ProductCreateParams(
      sku: _skuController.text.trim(),
      name: _nameController.text.trim(),
      description: _emptyToNull(_descriptionController.text),
      categoryId: _categoryId,
      brandId: _brandId,
      baseUnitId: _baseUnitId!,
      gender: _gender,
      season: _emptyToNull(_seasonController.text),
      ageGroup: _emptyToNull(_ageGroupController.text),
      hsnCode: _emptyToNull(_hsnCodeController.text),
      taxPercent: MoneyFormat.parseToWire(_taxPercentController.text),
      trackInventory: _trackInventory,
      allowNegativeStock: _allowNegativeStock,
      lowStockThreshold: int.tryParse(_lowStockThresholdController.text.trim()),
      hasVariants: _hasVariants,
      purchasePrice:
          MoneyFormat.parseToWire(_purchasePriceController.text) ?? '0',
      sellingPrice:
          MoneyFormat.parseToWire(_sellingPriceController.text) ?? '0',
      mrp: MoneyFormat.parseToWire(_mrpController.text),
      variants: _hasVariants
          ? _variantRows
                .map(
                  (row) => ProductVariantInputParams(
                    sku: row.skuController.text.trim(),
                    size: _emptyToNull(row.sizeController.text),
                    color: _emptyToNull(row.colorController.text),
                    purchasePrice:
                        MoneyFormat.parseToWire(
                          row.purchasePriceController.text,
                        ) ??
                        '0',
                    sellingPrice:
                        MoneyFormat.parseToWire(
                          row.sellingPriceController.text,
                        ) ??
                        '0',
                    mrp: MoneyFormat.parseToWire(row.mrpController.text),
                  ),
                )
                .toList()
          : const [],
    );

    final result = await ref.read(productListProvider.notifier).create(params);

    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _isSubmitting = false;
        _errorMessage = failure.userMessage;
      }),
      (productWithVariants) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${productWithVariants.product.name} created'),
          ),
        );
        Navigator.of(context).pop(productWithVariants.product.id);
      },
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
    final units = ref
        .watch(unitsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <UnitOfMeasure>[],
        );

    return Scaffold(
      appBar: AppBar(title: const Text('New product')),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 720 : double.infinity,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Identification',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _skuController,
                            decoration: const InputDecoration(
                              labelText: 'SKU *',
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'SKU is required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name *',
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'Name is required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Classification',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 220,
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
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _brandId,
                            decoration: const InputDecoration(
                              labelText: 'Brand',
                            ),
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
                            onChanged: (value) =>
                                setState(() => _brandId = value),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: _baseUnitId,
                            decoration: const InputDecoration(
                              labelText: 'Base unit *',
                            ),
                            items: units
                                .map(
                                  (u) => DropdownMenuItem<String>(
                                    value: u.id,
                                    child: Text(
                                      '${u.name} (${u.abbreviation})',
                                    ),
                                  ),
                                )
                                .toList(),
                            validator: (value) =>
                                value == null ? 'Unit is required' : null,
                            onChanged: (value) =>
                                setState(() => _baseUnitId = value),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<ProductGender?>(
                            initialValue: _gender,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                            ),
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
                            onChanged: (value) =>
                                setState(() => _gender = value),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextFormField(
                            controller: _seasonController,
                            decoration: const InputDecoration(
                              labelText: 'Season',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextFormField(
                            controller: _ageGroupController,
                            decoration: const InputDecoration(
                              labelText: 'Age group',
                              hintText: 'e.g. 4-6y',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tax & inventory',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 220,
                          child: TextFormField(
                            controller: _hsnCodeController,
                            decoration: const InputDecoration(
                              labelText: 'HSN code',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextFormField(
                            controller: _taxPercentController,
                            decoration: const InputDecoration(
                              labelText: 'Tax %',
                            ),
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
                        SizedBox(
                          width: 220,
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
                      onChanged: (value) =>
                          setState(() => _trackInventory = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow negative stock'),
                      value: _allowNegativeStock,
                      onChanged: (value) =>
                          setState(() => _allowNegativeStock = value),
                    ),
                    const Divider(height: 32),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Has variants'),
                      subtitle: const Text(
                        'Turn on for products sold in multiple sizes/colors (e.g. Kids Wear).',
                      ),
                      value: _hasVariants,
                      onChanged: (value) =>
                          setState(() => _hasVariants = value),
                    ),
                    const SizedBox(height: 8),
                    if (!_hasVariants) ...[
                      Text(
                        'Pricing',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 220,
                            child: TextFormField(
                              controller: _purchasePriceController,
                              decoration: const InputDecoration(
                                labelText: 'Purchase price',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) =>
                                  MoneyFormat.isValid(value ?? '')
                                  ? null
                                  : 'Invalid amount',
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextFormField(
                              controller: _sellingPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Selling price',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) =>
                                  MoneyFormat.isValid(value ?? '')
                                  ? null
                                  : 'Invalid amount',
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextFormField(
                              controller: _mrpController,
                              decoration: const InputDecoration(
                                labelText: 'MRP',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) =>
                                  (value != null &&
                                      value.trim().isNotEmpty &&
                                      !MoneyFormat.isValid(value))
                                  ? 'Invalid amount'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Variants',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _addVariantRow,
                            icon: const Icon(Icons.add),
                            label: const Text('Add variant'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _variantRows.length; i++)
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Variant ${i + 1}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelLarge,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Remove',
                                      onPressed: () => _removeVariantRow(i),
                                    ),
                                  ],
                                ),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: 180,
                                      child: TextFormField(
                                        controller:
                                            _variantRows[i].skuController,
                                        decoration: const InputDecoration(
                                          labelText: 'Variant SKU *',
                                        ),
                                        validator: (value) =>
                                            (_hasVariants &&
                                                (value == null ||
                                                    value.trim().isEmpty))
                                            ? 'Required'
                                            : null,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: TextFormField(
                                        controller:
                                            _variantRows[i].sizeController,
                                        decoration: const InputDecoration(
                                          labelText: 'Size',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: TextFormField(
                                        controller:
                                            _variantRows[i].colorController,
                                        decoration: const InputDecoration(
                                          labelText: 'Color',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 150,
                                      child: TextFormField(
                                        controller: _variantRows[i]
                                            .purchasePriceController,
                                        decoration: const InputDecoration(
                                          labelText: 'Purchase price',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        validator: (value) =>
                                            MoneyFormat.isValid(value ?? '')
                                            ? null
                                            : 'Invalid',
                                      ),
                                    ),
                                    SizedBox(
                                      width: 150,
                                      child: TextFormField(
                                        controller: _variantRows[i]
                                            .sellingPriceController,
                                        decoration: const InputDecoration(
                                          labelText: 'Selling price',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        validator: (value) =>
                                            MoneyFormat.isValid(value ?? '')
                                            ? null
                                            : 'Invalid',
                                      ),
                                    ),
                                    SizedBox(
                                      width: 150,
                                      child: TextFormField(
                                        controller:
                                            _variantRows[i].mrpController,
                                        decoration: const InputDecoration(
                                          labelText: 'MRP',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_variantRows.isEmpty)
                        Text(
                          'Add at least one variant.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create product'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
