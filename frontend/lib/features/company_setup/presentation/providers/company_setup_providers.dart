import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/company_setup_remote_data_source.dart';
import '../../data/repositories/company_setup_repository_impl.dart';
import '../../domain/repositories/company_setup_repository.dart';

part 'company_setup_providers.g.dart';

@riverpod
CompanySetupRepository companySetupRepository(Ref ref) {
  return CompanySetupRepositoryImpl(
    CompanySetupRemoteDataSource(ref.watch(dioProvider)),
    ref.watch(tokenStorageProvider),
  );
}
