import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_x.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../providers/inventory_providers.dart';

enum _MovementDirection { stockIn, stockOut }

Future<bool?> showStockInDialog(
  BuildContext context, {
  required String productVariantId,
  required String productLabel,
  String? initialWarehouseId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _StockMovementDialog(
      direction: _MovementDirection.stockIn,
      productVariantId: productVariantId,
      productLabel: productLabel,
      initialWarehouseId: initialWarehouseId,
    ),
  );
}

Future<bool?> showStockOutDialog(
  BuildContext context, {
  required String productVariantId,
  required String productLabel,
  String? initialWarehouseId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _StockMovementDialog(
      direction: _MovementDirection.stockOut,
      productVariantId: productVariantId,
      productLabel: productLabel,
      initialWarehouseId: initialWarehouseId,
    ),
  );
}

class _StockMovementDialog extends ConsumerStatefulWidget {
  const _StockMovementDialog({
    required this.direction,
    required this.productVariantId,
    required this.productLabel,
    this.initialWarehouseId,
  });

  final _MovementDirection direction;
  final String productVariantId;
  final String productLabel;
  final String? initialWarehouseId;

  @override
  ConsumerState<_StockMovementDialog> createState() =>
      _StockMovementDialogState();
}

class _StockMovementDialogState extends ConsumerState<_StockMovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _noteController = TextEditingController();
  String? _warehouseId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _warehouseId = widget.initialWarehouseId;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _noteController.dispose();
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

    final quantity = int.parse(_quantityController.text.trim());
    final notifier = ref.read(stockListProvider.notifier);
    final result = widget.direction == _MovementDirection.stockIn
        ? await notifier.stockIn(
            StockInParams(
              warehouseId: _warehouseId!,
              productVariantId: widget.productVariantId,
              quantity: quantity,
              reason: _emptyToNull(_reasonController.text),
              note: _emptyToNull(_noteController.text),
            ),
          )
        : await notifier.stockOut(
            StockOutParams(
              warehouseId: _warehouseId!,
              productVariantId: widget.productVariantId,
              quantity: quantity,
              reason: _emptyToNull(_reasonController.text),
              note: _emptyToNull(_noteController.text),
            ),
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
    final isStockIn = widget.direction == _MovementDirection.stockIn;
    final warehouses = ref
        .watch(warehousesProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <Warehouse>[]);

    return AlertDialog(
      title: Text(isStockIn ? 'Stock in' : 'Stock out'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.productLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _warehouseId,
                  decoration: const InputDecoration(labelText: 'Warehouse *'),
                  items: warehouses
                      .map(
                        (w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)),
                      )
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Warehouse is required' : null,
                  onChanged: (value) => setState(() => _warehouseId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity *'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    return (parsed == null || parsed <= 0)
                        ? 'Enter a positive whole number'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 2,
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
              : Text(isStockIn ? 'Record stock in' : 'Record stock out'),
        ),
      ],
    );
  }
}
