import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/bootstrap/presentation/screens/bootstrap_screen.dart';

part 'app_router.g.dart';

/// Route guards (auth required, tenant selected, etc.) are added here in
/// Sprint 2 once there is a session to guard against — see
/// SPRINT0.md §2.3.
@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (context, state) => const BootstrapScreen())],
  );
}
