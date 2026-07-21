import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retailos/core/error/failure.dart';
import 'package:retailos/features/bootstrap/data/datasources/health_remote_data_source.dart';
import 'package:retailos/features/bootstrap/data/repositories/health_repository_impl.dart';
import 'package:retailos/features/bootstrap/domain/entities/api_health.dart';

class _MockHealthRemoteDataSource extends Mock implements HealthRemoteDataSource {}

void main() {
  late _MockHealthRemoteDataSource dataSource;
  late HealthRepositoryImpl repository;

  setUp(() {
    dataSource = _MockHealthRemoteDataSource();
    repository = HealthRepositoryImpl(dataSource);
  });

  test('returns Right(ApiHealth) when the data source succeeds', () async {
    const health = ApiHealth(status: 'ok', environment: 'development');
    when(() => dataSource.fetchHealth()).thenAnswer((_) async => health);

    final result = await repository.check();

    expect(result.getRight().toNullable(), health);
  });

  test('maps a connection-error DioException to Failure.network', () async {
    when(() => dataSource.fetchHealth()).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/health'),
        type: DioExceptionType.connectionError,
      ),
    );

    final result = await repository.check();

    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
  });

  test('maps a non-2xx DioException to Failure.server with the status code', () async {
    when(() => dataSource.fetchHealth()).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/health'),
        response: Response(requestOptions: RequestOptions(path: '/health'), statusCode: 503),
        type: DioExceptionType.badResponse,
      ),
    );

    final result = await repository.check();

    final failure = result.getLeft().toNullable();
    expect(failure, isA<ServerFailure>());
    expect((failure as ServerFailure).statusCode, 503);
  });

  test('maps any other thrown error to Failure.unexpected', () async {
    when(() => dataSource.fetchHealth()).thenThrow(StateError('boom'));

    final result = await repository.check();

    expect(result.getLeft().toNullable(), isA<UnexpectedFailure>());
  });
}
