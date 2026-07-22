import 'package:freezed_annotation/freezed_annotation.dart';

part 'unit_of_measure.freezed.dart';

/// Named `UnitOfMeasure` rather than `Unit` to avoid colliding with
/// fpdart's `Unit`/`unit` (used throughout this codebase for
/// `Either<Failure, Unit>` void-success results).
@freezed
abstract class UnitOfMeasure with _$UnitOfMeasure {
  const factory UnitOfMeasure({
    required String id,
    String? companyId,
    required String name,
    required String abbreviation,
    required bool isSystem,
  }) = _UnitOfMeasure;
}
