import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retailos/core/error/failure.dart';
import 'package:retailos/core/network/token_storage.dart';
import 'package:retailos/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:retailos/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:retailos/features/auth/domain/entities/branch_summary.dart';
import 'package:retailos/features/auth/domain/entities/current_user.dart';

class _MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockAuthRemoteDataSource dataSource;
  late _MockSecureStorage secureStorage;
  late TokenStorage tokenStorage;
  late AuthRepositoryImpl repository;

  const user = CurrentUser(
    userId: 'user-1',
    companyId: 'company-1',
    branchId: 'branch-1',
    email: 'owner@example.com',
    fullName: 'Ada Owner',
    permissions: ['company.read'],
  );

  setUp(() {
    dataSource = _MockAuthRemoteDataSource();
    secureStorage = _MockSecureStorage();
    tokenStorage = TokenStorage(storage: secureStorage);
    repository = AuthRepositoryImpl(dataSource, tokenStorage);

    when(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => secureStorage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  });

  group('login', () {
    test('persists tokens and returns the current user on success', () async {
      when(
        () => dataSource.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          rememberMe: any(named: 'rememberMe'),
          deviceId: any(named: 'deviceId'),
          deviceName: any(named: 'deviceName'),
        ),
      ).thenAnswer((_) async => const LoginTokens(accessToken: 'access', refreshToken: 'refresh'));
      when(() => dataSource.me()).thenAnswer((_) async => user);

      final result = await repository.login(email: 'owner@example.com', password: 'secret1234');

      expect(result.getRight().toNullable(), user);
      verify(
        () => secureStorage.write(key: 'retailos.auth.access_token', value: 'access'),
      ).called(1);
      verify(
        () => secureStorage.write(key: 'retailos.auth.refresh_token', value: 'refresh'),
      ).called(1);
    });

    test('maps a 401 from the backend to Failure.auth without touching storage', () async {
      when(
        () => dataSource.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          rememberMe: any(named: 'rememberMe'),
          deviceId: any(named: 'deviceId'),
          deviceName: any(named: 'deviceName'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/auth/login'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/api/v1/auth/login'),
            statusCode: 401,
            data: <String, dynamic>{
              'success': false,
              'message': 'Invalid email or password',
              'errors': <dynamic>[],
            },
          ),
        ),
      );

      final result = await repository.login(email: 'owner@example.com', password: 'wrong');

      final failure = result.getLeft().toNullable();
      expect(failure, isA<AuthFailure>());
      expect((failure as AuthFailure).message, 'Invalid email or password');
      verifyNever(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      );
    });
  });

  group('hasStoredSession', () {
    test('is true when a refresh token is stored', () async {
      when(
        () => secureStorage.read(key: 'retailos.auth.refresh_token'),
      ).thenAnswer((_) async => 'refresh');

      expect(await repository.hasStoredSession(), isTrue);
    });

    test('is false when nothing is stored', () async {
      when(() => secureStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);

      expect(await repository.hasStoredSession(), isFalse);
    });
  });

  group('logout', () {
    test('clears stored tokens even when no refresh token exists', () async {
      when(() => secureStorage.read(key: any(named: 'key'))).thenAnswer((_) async => null);

      final result = await repository.logout();

      expect(result.isRight(), isTrue);
      verify(() => secureStorage.delete(key: 'retailos.auth.access_token')).called(1);
      verify(() => secureStorage.delete(key: 'retailos.auth.refresh_token')).called(1);
    });

    test('calls the remote logout endpoint when a refresh token exists', () async {
      when(
        () => secureStorage.read(key: 'retailos.auth.refresh_token'),
      ).thenAnswer((_) async => 'refresh');
      when(
        () => secureStorage.read(key: 'retailos.auth.access_token'),
      ).thenAnswer((_) async => null);
      when(() => dataSource.logout(any())).thenAnswer((_) async {});

      await repository.logout();

      verify(() => dataSource.logout('refresh')).called(1);
    });
  });

  group('switchBranch', () {
    test('updates only the access token', () async {
      when(() => dataSource.switchBranch(any())).thenAnswer((_) async => 'new-access-token');

      final result = await repository.switchBranch('branch-2');

      expect(result.isRight(), isTrue);
      verify(
        () => secureStorage.write(key: 'retailos.auth.access_token', value: 'new-access-token'),
      ).called(1);
      verifyNever(
        () => secureStorage.write(
          key: 'retailos.auth.refresh_token',
          value: any(named: 'value'),
        ),
      );
    });
  });

  group('fetchCurrentUser', () {
    test('returns the user on success', () async {
      when(() => dataSource.me()).thenAnswer((_) async => user);

      final result = await repository.fetchCurrentUser();

      expect(result.getRight().toNullable(), user);
    });
  });

  group('forgotPassword', () {
    test('delegates to the data source', () async {
      when(() => dataSource.forgotPassword(any())).thenAnswer((_) async {});

      final result = await repository.forgotPassword('owner@example.com');

      expect(result.isRight(), isTrue);
      verify(() => dataSource.forgotPassword('owner@example.com')).called(1);
    });
  });

  group('resetPassword', () {
    test('delegates to the data source', () async {
      when(
        () => dataSource.resetPassword(
          token: any(named: 'token'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.resetPassword(token: 'tok', newPassword: 'new-pass-123');

      expect(result.isRight(), isTrue);
      verify(() => dataSource.resetPassword(token: 'tok', newPassword: 'new-pass-123')).called(1);
    });
  });

  group('changePassword', () {
    test('delegates to the data source', () async {
      when(
        () => dataSource.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.changePassword(
        currentPassword: 'old-pass',
        newPassword: 'new-pass-123',
      );

      expect(result.isRight(), isTrue);
    });
  });

  group('myBranches', () {
    test('returns the branch list from the data source', () async {
      when(
        () => dataSource.myBranches(),
      ).thenAnswer((_) async => [const BranchSummary(id: 'b1', name: 'Head Office', code: 'HO')]);

      final result = await repository.myBranches();

      final branches = result.getRight().toNullable();
      expect(branches, hasLength(1));
      expect(branches!.first.name, 'Head Office');
    });
  });
}
