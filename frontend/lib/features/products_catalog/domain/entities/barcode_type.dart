/// Mirrors backend `BarcodeType` (app/modules/products_catalog/models.py).
enum BarcodeType {
  ean13('ean13', 'EAN-13'),
  upcA('upc_a', 'UPC-A'),
  code128('code128', 'Code 128'),
  internal('internal', 'Internal');

  const BarcodeType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static BarcodeType fromWire(String value) =>
      BarcodeType.values.firstWhere((t) => t.wireValue == value);
}
