import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retailos/core/error/failure.dart';
import 'package:retailos/core/network/token_storage.dart';
import 'package:retailos/features/company_setup/data/datasources/company_setup_remote_data_source.dart';
import 'package:retailos/features/company_setup/data/repositories/company_setup_repository_impl.dart';
import 'package:retailos/features/company_setup/domain/repositories/company_setup_repository.dart';

class _MockCompanySetupRemoteDataSource extends Mock implements CompanySetupRemoteDataSource {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockCompanySetupRemoteDataSource dataSource;
  late _MockSecureStorage secureStorage;
  late CompanySetupRepositoryImpl repository;

  const params = CompanySignupParams(
    companyName: 'Acme Retail',
    currency: 'INR',
    ownerFullName: 'Ada Owner',
    ownerEmail: 'owner@example.com',
    ownerPassword: 'correct-horse-battery-staple',
  );

  setUpAll(() {
    registerFallbackValue(params);
  });

  setUp(() {
    dataSource = _MockCompanySetupRemoteDataSource();
    secureStorage = _MockSecureStorage();
    repository = CompanySetupRepositoryImpl(dataSource, TokenStorage(storage: secureStorage));
    when(
      () => secureStorage.write(key: any(named: 'key'), value: any(named: 'value')),
    ).thenAnswer((_) async {});
  });

  test('persists tokens on success', () async {
    when(
      () => dataSource.signUp(any()),
    ).thenAnswer((_) async => const SignupTokens(accessToken: 'access', refreshToken: 'refresh'));

    final result = await repository.signUp(params);

    expect(result.isRight(), isTrue);
    verify(
      () => secureStorage.write(key: 'retailos.auth.access_token', value: 'access'),
    ).called(1);
    verify(
      () => secureStorage.write(key: 'retailos.auth.refresh_token', value: 'refresh'),
    ).called(1);
  });

  test('maps a 422 (duplicate email) to Failure.validation', () async {
    when(() => dataSource.signUp(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/v1/companies'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/companies'),
          statusCode: 422,
          data: <String, dynamic>{
            'success': false,
            'message': 'Email is already registered',
            'errors': <dynamic>[],
          },
        ),
      ),
    );

    final result = await repository.signUp(params);

    expect(result.getLeft().toNullable(), isA<ValidationFailure>());
  });
}
