import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_x.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../providers/inventory_providers.dart';

/// Takes the physically recounted total, not a delta — matches the
/// backend's `AdjustmentRequest.counted_quantity` contract exactly (see
/// `InventoryService.adjust`'s docstring for why: the server computes
/// the delta from a value read under the same row lock that applies it,
/// so there's no client/server race on "what was the count a moment
/// ago").
Future<bool?> showAdjustmentFormDialog(
  BuildContext context, {
  required String productVariantId,
  required String productLabel,
  required int currentQuantity,
  String? initialWarehouseId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _AdjustmentFormDialog(
      productVariantId: productVariantId,
      productLabel: productLabel,
      currentQuantity: currentQuantity,
      initialWarehouseId: initialWarehouseId,
    ),
  );
}

class _AdjustmentFormDialog extends ConsumerStatefulWidget {
  const _AdjustmentFormDialog({
    required this.productVariantId,
    required this.productLabel,
    required this.currentQuantity,
    this.initialWarehouseId,
  });

  final String productVariantId;
  final String productLabel;
  final int currentQuantity;
  final String? initialWarehouseId;

  @override
  ConsumerState<_AdjustmentFormDialog> createState() =>
      _AdjustmentFormDialogState();
}

class _AdjustmentFormDialogState extends ConsumerState<_AdjustmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _countedQuantityController;
  final _reasonController = TextEditingController();
  final _noteController = TextEditingController();
  String? _warehouseId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _warehouseId = widget.initialWarehouseId;
    _countedQuantityController = TextEditingController(
      text: widget.currentQuantity.toString(),
    );
  }

  @override
  void dispose() {
    _countedQuantityController.dispose();
    _reasonController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(stockListProvider.notifier)
        .adjust(
          AdjustmentParams(
            warehouseId: _warehouseId!,
            productVariantId: widget.productVariantId,
            countedQuantity: int.parse(_countedQuantityController.text.trim()),
            reason: _reasonController.text.trim(),
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
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
    final warehouses = ref
        .watch(warehousesProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <Warehouse>[]);

    return AlertDialog(
      title: const Text('Adjust stock (recount)'),
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
                Text(
                  'Current recorded quantity: ${widget.currentQuantity}',
                  style: Theme.of(context).textTheme.bodySmall,
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
                  controller: _countedQuantityController,
                  decoration: const InputDecoration(
                    labelText: 'Counted quantity *',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    return (parsed == null || parsed < 0)
                        ? 'Enter a whole number, 0 or more'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(labelText: 'Reason *'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Reason is required'
                      : null,
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
              : const Text('Save adjustment'),
        ),
      ],
    );
  }
}
