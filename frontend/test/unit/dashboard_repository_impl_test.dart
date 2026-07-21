import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retailos/core/error/failure.dart';
import 'package:retailos/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:retailos/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:retailos/features/dashboard/domain/entities/dashboard_shell.dart';

class _MockDashboardRemoteDataSource extends Mock implements DashboardRemoteDataSource {}

void main() {
  late _MockDashboardRemoteDataSource dataSource;
  late DashboardRepositoryImpl repository;

  const shell = DashboardShell(
    companyName: 'Acme Retail',
    branchName: 'Head Office',
    userFullName: 'Ada Owner',
    roleNames: ['Super Admin'],
    apiStatus: 'ok',
    databaseStatus: 'ok',
    apiVersion: '0.1.0',
  );

  setUp(() {
    dataSource = _MockDashboardRemoteDataSource();
    repository = DashboardRepositoryImpl(dataSource);
  });

  test('returns the shell on success', () async {
    when(() => dataSource.fetchShell()).thenAnswer((_) async => shell);

    final result = await repository.fetchShell();

    expect(result.getRight().toNullable(), shell);
  });

  test('maps a connection error to Failure.network', () async {
    when(() => dataSource.fetchShell()).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/v1/dashboard/shell'),
        type: DioExceptionType.connectionError,
      ),
    );

    final result = await repository.fetchShell();

    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
  });

  test('maps any other thrown error to Failure.unexpected', () async {
    when(() => dataSource.fetchShell()).thenThrow(StateError('boom'));

    final result = await repository.fetchShell();

    expect(result.getLeft().toNullable(), isA<UnexpectedFailure>());
  });
}
