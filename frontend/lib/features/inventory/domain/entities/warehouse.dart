import 'package:freezed_annotation/freezed_annotation.dart';

part 'warehouse.freezed.dart';

/// No dedicated `company` Flutter feature exists yet (Sprint 2 was
/// backend-only for warehouses) — kept here since Inventory is
/// currently the only Flutter consumer of warehouse data. Move to a
/// shared feature if a second consumer shows up.
@freezed
abstract class Warehouse with _$Warehouse {
  const factory Warehouse({
    required String id,
    required String companyId,
    required String branchId,
    required String name,
    required String code,
    required bool isDefault,
    required bool isActive,
  }) = _Warehouse;
}
