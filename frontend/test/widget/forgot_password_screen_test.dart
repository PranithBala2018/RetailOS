import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:retailos/core/error/failure.dart';
import 'package:retailos/features/auth/domain/entities/branch_summary.dart';
import 'package:retailos/features/auth/domain/entities/current_user.dart';
import 'package:retailos/features/auth/domain/repositories/auth_repository.dart';
import 'package:retailos/features/auth/presentation/providers/auth_providers.dart';
import 'package:retailos/features/auth/presentation/screens/forgot_password_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  String? capturedEmail;

  @override
  Future<bool> hasStoredSession() async => false;

  @override
  Future<Either<Failure, CurrentUser>> login({
    required String email,
    required String password,
    bool rememberMe = false,
    String? deviceId,
    String? deviceName,
  }) async => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> logout() async => const Right(null);

  @override
  Future<Either<Failure, CurrentUser>> fetchCurrentUser() async => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> forgotPassword(String email) async {
    capturedEmail = email;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String token,
    required String newPassword,
  }) async => const Right(null);

  @override
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => const Right(null);

  @override
  Future<Either<Failure, List<BranchSummary>>> myBranches() async => const Right([]);

  @override
  Future<Either<Failure, void>> switchBranch(String branchId) async => const Right(null);
}

Widget _wrap(AuthRepository repository) {
  final router = GoRouter(
    initialLocation: '/forgot-password',
    routes: [
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('Login')),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const Scaffold(body: Text('Reset')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('requires an email before submitting', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthRepository()));
    await tester.tap(find.text('Send reset link'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
  });

  testWidgets('shows a generic confirmation after submitting', (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(_wrap(repository));

    await tester.enterText(find.byType(TextFormField), 'owner@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    await tester.pump();

    expect(repository.capturedEmail, 'owner@example.com');
    expect(
      find.text('If that email is registered, a password reset link has been sent.'),
      findsOneWidget,
    );
  });
}
