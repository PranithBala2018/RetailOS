import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/failure.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/current_user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_providers.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    AuthRemoteDataSource(ref.watch(dioProvider)),
    ref.watch(tokenStorageProvider),
  );
}

/// `null` means "not authenticated". Building this provider is what the
/// Splash screen watches to decide where to route — see SPRINT0.md §2.3;
/// this is the seam route guards attach to.
@riverpod
class Session extends _$Session {
  @override
  Future<CurrentUser?> build() async {
    final repository = ref.watch(authRepositoryProvider);
    if (!await repository.hasStoredSession()) {
      return null;
    }
    final result = await repository.fetchCurrentUser();
    return result.match((failure) => null, (user) => user);
  }

  /// Assumes this notifier's initial `build()` has already resolved —
  /// true by construction in the real app, since the router only ever
  /// reaches a screen that calls `login()` after Splash has watched
  /// `sessionProvider` to completion (see core/router/app_router.dart's
  /// `redirect`). Tests that mount a screen calling this in isolation
  /// must pre-warm the provider the same way — see
  /// test/widget/login_screen_test.dart's `_wrap` helper.
  Future<Either<Failure, Unit>> login({
    required String email,
    required String password,
    bool rememberMe = false,
    String? deviceId,
    String? deviceName,
  }) async {
    final previousUser = switch (state) {
      AsyncData(:final value) => value,
      _ => null,
    };
    state = const AsyncLoading();
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.login(
      email: email,
      password: password,
      rememberMe: rememberMe,
      deviceId: deviceId,
      deviceName: deviceName,
    );
    return result.match(
      (failure) {
        state = AsyncData(previousUser);
        return Left(failure);
      },
      (user) {
        state = AsyncData(user);
        return const Right(unit);
      },
    );
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.logout();
    state = const AsyncData(null);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// After branch-switching persists a new access token, refresh the
  /// in-memory user so `branchId` reflects the switch immediately.
  Future<void> reloadCurrentUser() async {
    final repository = ref.read(authRepositoryProvider);
    final result = await repository.fetchCurrentUser();
    result.match((failure) {}, (user) => state = AsyncData(user));
  }
}
