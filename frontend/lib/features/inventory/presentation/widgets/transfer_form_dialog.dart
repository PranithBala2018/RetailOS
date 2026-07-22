import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure_x.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../providers/inventory_providers.dart';

Future<bool?> showTransferFormDialog(
  BuildContext context, {
  required String productVariantId,
  required String productLabel,
  String? initialFromWarehouseId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _TransferFormDialog(
      productVariantId: productVariantId,
      productLabel: productLabel,
      initialFromWarehouseId: initialFromWarehouseId,
    ),
  );
}

class _TransferFormDialog extends ConsumerStatefulWidget {
  const _TransferFormDialog({
    required this.productVariantId,
    required this.productLabel,
    this.initialFromWarehouseId,
  });

  final String productVariantId;
  final String productLabel;
  final String? initialFromWarehouseId;

  @override
  ConsumerState<_TransferFormDialog> createState() =>
      _TransferFormDialogState();
}

class _TransferFormDialogState extends ConsumerState<_TransferFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  String? _fromWarehouseId;
  String? _toWarehouseId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fromWarehouseId = widget.initialFromWarehouseId;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromWarehouseId == _toWarehouseId) {
      setState(
        () => _errorMessage =
            'Source and destination warehouse must be different.',
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(stockListProvider.notifier)
        .transfer(
          TransferParams(
            fromWarehouseId: _fromWarehouseId!,
            toWarehouseId: _toWarehouseId!,
            productVariantId: widget.productVariantId,
            quantity: int.parse(_quantityController.text.trim()),
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
      title: const Text('Transfer stock'),
      content: SizedBox(
        width: 420,
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
                  initialValue: _fromWarehouseId,
                  decoration: const InputDecoration(
                    labelText: 'From warehouse *',
                  ),
                  items: warehouses
                      .map(
                        (w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)),
                      )
                      .toList(),
                  validator: (value) => value == null ? 'Required' : null,
                  onChanged: (value) =>
                      setState(() => _fromWarehouseId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _toWarehouseId,
                  decoration: const InputDecoration(
                    labelText: 'To warehouse *',
                  ),
                  items: warehouses
                      .map(
                        (w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)),
                      )
                      .toList(),
                  validator: (value) => value == null ? 'Required' : null,
                  onChanged: (value) => setState(() => _toWarehouseId = value),
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
              : const Text('Transfer'),
        ),
      ],
    );
  }
}
