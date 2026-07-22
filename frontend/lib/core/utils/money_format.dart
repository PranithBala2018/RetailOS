import 'package:intl/intl.dart';

/// Formats and validates the wire-format price `String`s the backend
/// sends (a `Decimal` serialized as e.g. `"120.00"` — see
/// `products_catalog`'s entity docs). Deliberately does *not* introduce a
/// `Decimal`/`Money` type: the app has no client-side money arithmetic
/// yet, only display and round-trip, so a plain `String` plus these
/// helpers is the simplest thing that's still correct.
abstract final class MoneyFormat {
  static final NumberFormat _display = NumberFormat.currency(
    symbol: '',
    decimalDigits: 2,
  );

  /// `"120"` / `"120.5"` / `"120.00"` -> `"120.00"` for display.
  static String display(String? wireValue) {
    if (wireValue == null || wireValue.isEmpty) return '0.00';
    final parsed = num.tryParse(wireValue);
    if (parsed == null) return wireValue;
    return _display.format(parsed).trim();
  }

  /// Normalizes free-form user input (e.g. `"120"`, `" 120.5 "`) into the
  /// `"120.00"`-style wire format the backend expects, or `null` if the
  /// input isn't a valid non-negative number.
  static String? parseToWire(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final parsed = num.tryParse(trimmed);
    if (parsed == null || parsed < 0) return null;
    return parsed.toStringAsFixed(2);
  }

  static bool isValid(String input) => parseToWire(input) != null;
}
