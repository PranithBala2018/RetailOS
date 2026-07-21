import 'package:dio/dio.dart';

import '../../domain/entities/api_health.dart';

class HealthRemoteDataSource {
  HealthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<ApiHealth> fetchHealth() async {
    final response = await _dio.get<Map<String, dynamic>>('/health');
    final data = response.data!['data'] as Map<String, dynamic>;
    return ApiHealth(status: data['status'] as String, environment: data['environment'] as String);
  }
}
