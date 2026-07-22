import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/current_user.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';

/// Shows [child] only if the signed-in user's RBAC permission set (see
/// `CurrentUser.permissions`/`.can()`) contains [permission]. Renders
/// [fallback] (defaults to nothing) otherwise — used to hide
/// create/edit/delete/export/import affordances a Cashier-role user
/// isn't allowed to act on, matching the backend's `require_permission`
/// gates instead of just relying on the API to reject the request.
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
  });

  final String permission;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = switch (ref.watch(sessionProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final allowed = user?.can(permission) ?? false;
    return allowed ? child : (fallback ?? const SizedBox.shrink());
  }
}
