import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../../../../core/network/token_storage.dart';
import '../../domain/entities/branch_summary.dart';
import '../../domain/entities/current_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource, this._tokenStorage);

  final AuthRemoteDataSource _remoteDataSource;
  final TokenStorage _tokenStorage;

  @override
  Future<Either<Failure, CurrentUser>> login({
    required String email,
    required String password,
    bool rememberMe = false,
    String? deviceId,
    String? deviceName,
  }) async {
    try {
      final tokens = await _remoteDataSource.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
        deviceId: deviceId,
        deviceName: deviceName,
      );
      await _tokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      final user = await _remoteDataSource.me();
      return Right(user);
    } on DioException catch (e) {
      return Left(mapDioException(e));
    } catch (e) {
      return Left(Failure.unexpected(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      final refreshToken = await _tokenStorage.readRefreshToken();
      if (refreshToken != null) {
        await _remoteDataSource.logout(refreshToken);
      }
      await _tokenStorage.clear();
      return const Right(null);
    } on DioException catch (e) {
      // Clear locally regardless — an unreachable server shouldn't trap
      // the user in a logged-in UI they can no longer authenticate against.
      await _tokenStorage.clear();
      return Left(mapDioException(e));
    }
  }

  @override
  Future<bool> hasStoredSession() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    return refreshToken != null;
  }

  @override
  Future<Either<Failure, CurrentUser>> fetchCurrentUser() async {
    try {
      final user = await _remoteDataSource.me();
      return Right(user);
    } on DioException catch (e) {
      return Left(mapDioException(e));
    } catch (e) {
      return Left(Failure.unexpected(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> forgotPassword(String email) async {
    try {
      await _remoteDataSource.forgotPassword(email);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioException(e));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _remoteDataSource.resetPassword(token: token, newPassword: newPassword);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioException(e));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _remoteDataSource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioException(e));
    }
  }

  @override
  Future<Either<Failure, List<BranchSummary>>> myBranches() async {
    try {
      final branches = await _remoteDataSource.myBranches();
      return Right(branches);
    } on DioException catch (e) {
      return Left(mapDioException(e));
    }
  }

  @override
  Future<Either<Failure, void>> switchBranch(String branchId) async {
    try {
      final newAccessToken = await _remoteDataSource.switchBranch(branchId);
      await _tokenStorage.saveAccessToken(newAccessToken);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioException(e));
    }
  }
}
