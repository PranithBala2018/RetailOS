import 'package:freezed_annotation/freezed_annotation.dart';

part 'csv_import_summary.freezed.dart';

enum CsvImportRowStatus {
  created,
  skipped,
  error;

  static CsvImportRowStatus fromWire(String value) => switch (value) {
    'created' => CsvImportRowStatus.created,
    'skipped' => CsvImportRowStatus.skipped,
    'error' => CsvImportRowStatus.error,
    _ => CsvImportRowStatus.error,
  };
}

@freezed
abstract class CsvImportRowResult with _$CsvImportRowResult {
  const factory CsvImportRowResult({
    required String sku,
    required CsvImportRowStatus status,
    String? message,
  }) = _CsvImportRowResult;
}

@freezed
abstract class CsvImportSummary with _$CsvImportSummary {
  const factory CsvImportSummary({
    required int created,
    required int skipped,
    required int errors,
    required List<CsvImportRowResult> results,
  }) = _CsvImportSummary;
}
