import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../../domain/entities/dashboard_shell.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_data_source.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._remoteDataSource);

  final DashboardRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, DashboardShell>> fetchShell() async {
    try {
      final shell = await _remoteDataSource.fetchShell();
      return Right(shell);
    } on DioException catch (e) {
      return Left(mapDioException(e));
    } catch (e) {
      return Left(Failure.unexpected(message: e.toString()));
    }
  }
}
