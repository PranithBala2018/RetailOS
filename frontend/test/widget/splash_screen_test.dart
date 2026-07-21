import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:retailos/core/error/failure.dart';
import 'package:retailos/features/auth/domain/entities/branch_summary.dart';
import 'package:retailos/features/auth/domain/entities/current_user.dart';
import 'package:retailos/features/auth/domain/repositories/auth_repository.dart';
import 'package:retailos/features/auth/presentation/providers/auth_providers.dart';
import 'package:retailos/features/auth/presentation/screens/splash_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.storedSession});

  final bool storedSession;

  @override
  Future<bool> hasStoredSession() async => storedSession;

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
  Future<Either<Failure, CurrentUser>> fetchCurrentUser() async {
    return const Right(
      CurrentUser(
        userId: 'user-1',
        companyId: 'company-1',
        branchId: 'branch-1',
        email: 'owner@example.com',
        fullName: 'Ada Owner',
        permissions: [],
      ),
    );
  }

  @override
  Future<Either<Failure, void>> forgotPassword(String email) async => const Right(null);

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
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: SplashScreen()),
  );
}

void main() {
  testWidgets('shows a loading indicator while the session resolves', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthRepository(storedSession: false)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('RetailOS'), findsOneWidget);

    // Let the pending future resolve so the test doesn't leave it dangling.
    await tester.pump();
    await tester.pump();
  });

  testWidgets('stops loading once there is no stored session', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthRepository(storedSession: false)));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
