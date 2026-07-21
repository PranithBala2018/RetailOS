import 'package:dio/dio.dart';

import '../../domain/entities/dashboard_shell.dart';

class DashboardRemoteDataSource {
  DashboardRemoteDataSource(this._dio);

  final Dio _dio;

  Future<DashboardShell> fetchShell() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/dashboard/shell');
    final data = response.data!['data'] as Map<String, dynamic>;
    return DashboardShell(
      companyName: data['company_name'] as String,
      branchName: data['branch_name'] as String?,
      userFullName: data['user_full_name'] as String,
      roleNames: (data['role_names'] as List<dynamic>).cast<String>(),
      apiStatus: data['api_status'] as String,
      databaseStatus: data['database_status'] as String,
      apiVersion: data['api_version'] as String,
    );
  }
}
