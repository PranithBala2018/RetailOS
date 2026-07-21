import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/branch_selection/presentation/screens/branch_selection_screen.dart';
import '../../features/company_setup/presentation/screens/company_setup_wizard_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_shell_screen.dart';
import '../../features/dashboard/presentation/screens/navigation_shell_screen.dart';
import '../../features/dashboard/presentation/screens/profile_screen.dart';

part 'app_router.g.dart';

const _publicRoutes = {'/login', '/forgot-password', '/reset-password', '/company-setup'};

/// Bridges Riverpod's `sessionProvider` into the `Listenable` GoRouter
/// expects for `refreshListenable` — this is what lets the router
/// re-evaluate `redirect` in place when the session changes, instead of
/// the whole GoRouter (and its navigation stack) being torn down and
/// rebuilt the way it would be if `appRouterProvider` itself watched
/// `sessionProvider` directly.
class _SessionRefreshNotifier extends ChangeNotifier {
  _SessionRefreshNotifier(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refreshNotifier = _SessionRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final sessionAsync = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final isPublicRoute = _publicRoutes.contains(location);

      return sessionAsync.when(
        loading: () => location == '/splash' ? null : '/splash',
        error: (_, _) => isPublicRoute ? null : '/login',
        data: (user) {
          if (user == null) {
            return isPublicRoute ? null : '/login';
          }
          if (location == '/splash' || isPublicRoute) {
            return user.branchId == null ? '/branch-selection' : '/dashboard';
          }
          return null;
        },
      );
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
      GoRoute(
        path: '/company-setup',
        builder: (context, state) => const CompanySetupWizardScreen(),
      ),
      GoRoute(
        path: '/branch-selection',
        builder: (context, state) => const BranchSelectionScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => NavigationShellScreen(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) => const DashboardShellScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
    ],
  );
}
