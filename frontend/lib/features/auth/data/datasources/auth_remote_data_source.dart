import 'package:dio/dio.dart';

import '../../domain/entities/branch_summary.dart';
import '../../domain/entities/current_user.dart';

class LoginTokens {
  const LoginTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Raw API calls only — parses the `{"success", "message", "data"}`
/// envelope (API.md) directly into domain entities, matching the
/// pattern set in features/bootstrap (no separate Model layer for a
/// simple, one-directional JSON -> entity read).
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<LoginTokens> login({
    required String email,
    required String password,
    required bool rememberMe,
    String? deviceId,
    String? deviceName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: {
        'email': email,
        'password': password,
        'remember_me': rememberMe,
        'device_id': ?deviceId,
        'device_name': ?deviceName,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return LoginTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<void>('/api/v1/auth/logout', data: {'refresh_token': refreshToken});
  }

  Future<CurrentUser> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/auth/me');
    final data = response.data!['data'] as Map<String, dynamic>;
    return CurrentUser(
      userId: data['user_id'] as String,
      companyId: data['company_id'] as String,
      branchId: data['branch_id'] as String?,
      email: data['email'] as String,
      fullName: data['full_name'] as String,
      permissions: (data['permissions'] as List<dynamic>).cast<String>(),
    );
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post<void>('/api/v1/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({required String token, required String newPassword}) async {
    await _dio.post<void>(
      '/api/v1/auth/reset-password',
      data: {'token': token, 'new_password': newPassword},
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post<void>(
      '/api/v1/auth/change-password',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  Future<List<BranchSummary>> myBranches() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/auth/my-branches');
    final items = response.data!['data'] as List<dynamic>;
    return items
        .cast<Map<String, dynamic>>()
        .map(
          (b) => BranchSummary(
            id: b['id'] as String,
            name: b['name'] as String,
            code: b['code'] as String,
          ),
        )
        .toList();
  }

  Future<String> switchBranch(String branchId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/switch-branch',
      data: {'branch_id': branchId},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['access_token'] as String;
  }
}
