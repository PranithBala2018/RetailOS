import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:retailos/core/error/failure.dart';
import 'package:retailos/features/auth/domain/entities/branch_summary.dart';
import 'package:retailos/features/auth/domain/entities/current_user.dart';
import 'package:retailos/features/auth/domain/repositories/auth_repository.dart';
import 'package:retailos/features/auth/presentation/providers/auth_providers.dart';

const _user = CurrentUser(
  userId: 'user-1',
  companyId: 'company-1',
  branchId: 'branch-1',
  email: 'owner@example.com',
  fullName: 'Ada Owner',
  permissions: ['company.read'],
);

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.storedSession = false, this.loginResult});

  bool storedSession;
  Either<Failure, CurrentUser>? loginResult;
  int logoutCallCount = 0;

  @override
  Future<bool> hasStoredSession() async => storedSession;

  @override
  Future<Either<Failure, CurrentUser>> login({
    required String email,
    required String password,
    bool rememberMe = false,
    String? deviceId,
    String? deviceName,
  }) async => loginResult ?? const Right(_user);

  @override
  Future<Either<Failure, void>> logout() async {
    logoutCallCount++;
    return const Right(null);
  }

  @override
  Future<Either<Failure, CurrentUser>> fetchCurrentUser() async => const Right(_user);

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

void main() {
  test('build() resolves to null when there is no stored session', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(storedSession: false)),
      ],
    );
    addTearDown(container.dispose);

    final user = await container.read(sessionProvider.future);

    expect(user, isNull);
  });

  test('build() resolves to the current user when a stored session exists', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(storedSession: true)),
      ],
    );
    addTearDown(container.dispose);

    final user = await container.read(sessionProvider.future);

    expect(user, _user);
  });

  test('login() succeeds and updates state to the returned user', () async {
    final repository = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.future);

    final result = await container
        .read(sessionProvider.notifier)
        .login(email: 'owner@example.com', password: 'secret1234');

    expect(result.isRight(), isTrue);
    expect(container.read(sessionProvider).value, _user);
  });

  test('login() failure restores the previous (null) state and returns Left', () async {
    final repository = _FakeAuthRepository(
      loginResult: const Left(Failure.auth(message: 'Invalid email or password')),
    );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.future);

    final result = await container
        .read(sessionProvider.notifier)
        .login(email: 'owner@example.com', password: 'wrong');

    expect(result.isLeft(), isTrue);
    expect(container.read(sessionProvider).value, isNull);
  });

  test('logout() calls the repository and clears state', () async {
    final repository = _FakeAuthRepository(storedSession: true);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.future);
    expect(container.read(sessionProvider).value, _user);

    await container.read(sessionProvider.notifier).logout();

    expect(repository.logoutCallCount, 1);
    expect(container.read(sessionProvider).value, isNull);
  });

  test('reloadCurrentUser() refreshes state from the repository', () async {
    final repository = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.future);

    await container.read(sessionProvider.notifier).reloadCurrentUser();

    expect(container.read(sessionProvider).value, _user);
  });
}
