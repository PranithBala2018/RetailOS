import 'package:freezed_annotation/freezed_annotation.dart';

part 'branch_summary.freezed.dart';

@freezed
abstract class BranchSummary with _$BranchSummary {
  const factory BranchSummary({required String id, required String name, required String code}) =
      _BranchSummary;
}
