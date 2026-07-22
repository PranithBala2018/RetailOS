/// Mirrors backend `MovementType` (app/modules/inventory/models.py).
enum MovementType {
  stockIn('stock_in', 'Stock In'),
  stockOut('stock_out', 'Stock Out'),
  transferOut('transfer_out', 'Transfer Out'),
  transferIn('transfer_in', 'Transfer In'),
  adjustment('adjustment', 'Adjustment');

  const MovementType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static MovementType fromWire(String value) =>
      MovementType.values.firstWhere((t) => t.wireValue == value);
}
