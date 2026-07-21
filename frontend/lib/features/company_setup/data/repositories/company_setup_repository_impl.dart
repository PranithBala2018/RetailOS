import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../../../../core/network/token_storage.dart';
import '../../domain/repositories/company_setup_repository.dart';
import '../datasources/company_setup_remote_data_source.dart';

class CompanySetupRepositoryImpl implements CompanySetupRepository {
  CompanySetupRepositoryImpl(this._remoteDataSource, this._tokenStorage);

  final CompanySetupRemoteDataSource _remoteDataSource;
  final TokenStorage _tokenStorage;

  @override
  Future<Either<Failure, Unit>> signUp(CompanySignupParams params) async {
    try {
      final tokens = await _remoteDataSource.signUp(params);
      await _tokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return const Right(unit);
    } on DioException catch (e) {
      return Left(mapDioException(e));
    } catch (e) {
      return Left(Failure.unexpected(message: e.toString()));
    }
  }
}
