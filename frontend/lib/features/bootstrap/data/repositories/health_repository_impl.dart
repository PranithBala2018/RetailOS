import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/api_health.dart';
import '../../domain/repositories/health_repository.dart';
import '../datasources/health_remote_data_source.dart';

class HealthRepositoryImpl implements HealthRepository {
  HealthRepositoryImpl(this._remoteDataSource);

  final HealthRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, ApiHealth>> check() async {
    try {
      final health = await _remoteDataSource.fetchHealth();
      return Right(health);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return const Left(Failure.network());
      }
      return Left(Failure.server(statusCode: e.response?.statusCode, message: e.message));
    } catch (e) {
      return Left(Failure.unexpected(message: e.toString()));
    }
  }
}
