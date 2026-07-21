import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/health_remote_data_source.dart';
import '../../data/repositories/health_repository_impl.dart';
import '../../domain/entities/api_health.dart';
import '../../domain/repositories/health_repository.dart';

part 'health_providers.g.dart';

@riverpod
HealthRepository healthRepository(Ref ref) {
  return HealthRepositoryImpl(HealthRemoteDataSource(ref.watch(dioProvider)));
}

@riverpod
class HealthCheck extends _$HealthCheck {
  @override
  Future<ApiHealth> build() async {
    final result = await ref.watch(healthRepositoryProvider).check();
    return result.match((failure) => throw failure, (health) => health);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
