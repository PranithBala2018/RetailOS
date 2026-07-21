import 'package:freezed_annotation/freezed_annotation.dart';

part 'current_user.freezed.dart';

@freezed
abstract class CurrentUser with _$CurrentUser {
  const factory CurrentUser({
    required String userId,
    required String companyId,
    String? branchId,
    required String email,
    required String fullName,
    required List<String> permissions,
  }) = _CurrentUser;
}

extension CurrentUserPermissions on CurrentUser {
  bool can(String permissionCode) => permissions.contains(permissionCode);
}
