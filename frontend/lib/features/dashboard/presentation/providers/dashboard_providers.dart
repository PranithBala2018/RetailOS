import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/dashboard_remote_data_source.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_shell.dart';
import '../../domain/repositories/dashboard_repository.dart';

part 'dashboard_providers.g.dart';

@riverpod
DashboardRepository dashboardRepository(Ref ref) {
  return DashboardRepositoryImpl(DashboardRemoteDataSource(ref.watch(dioProvider)));
}

@riverpod
Future<DashboardShell> dashboardShell(Ref ref) async {
  final result = await ref.watch(dashboardRepositoryProvider).fetchShell();
  return result.match((failure) => throw failure, (shell) => shell);
}
