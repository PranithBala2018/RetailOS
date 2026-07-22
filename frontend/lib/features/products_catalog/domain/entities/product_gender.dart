/// Mirrors backend `ProductGender` (app/modules/products_catalog/models.py)
/// — Kids Wear pilot prep from Sprint 2, classifies the product listing;
/// size/color classify the variant instead (see [ProductVariant]).
enum ProductGender {
  men('men', 'Men'),
  women('women', 'Women'),
  kids('kids', 'Kids'),
  unisex('unisex', 'Unisex');

  const ProductGender(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ProductGender fromWire(String value) =>
      ProductGender.values.firstWhere((g) => g.wireValue == value);

  static ProductGender? fromWireOrNull(String? value) =>
      value == null ? null : fromWire(value);
}
