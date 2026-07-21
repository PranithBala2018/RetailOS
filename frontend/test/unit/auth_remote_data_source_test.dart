import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/features/auth/data/datasources/auth_remote_data_source.dart';

void main() {
  late HttpServer server;
  late Dio dio;
  late AuthRemoteDataSource dataSource;
  Map<String, dynamic>? lastRequestBody;
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic> Function() respond = () => <String, dynamic>{
    'success': true,
    'message': 'ok',
    'data': <String, dynamic>{},
  };

  setUp(() async {
    respond = () => <String, dynamic>{
      'success': true,
      'message': 'ok',
      'data': <String, dynamic>{},
    };
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      lastMethod = request.method;
      lastPath = request.uri.path;
      final bodyString = await utf8.decoder.bind(request).join();
      lastRequestBody = bodyString.isEmpty ? null : jsonDecode(bodyString) as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(respond()));
      await request.response.close();
    });
    dio = Dio(BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'));
    dataSource = AuthRemoteDataSource(dio);
  });

  tearDown(() async {
    await server.close(force: true);
    dio.close();
  });

  test('login posts credentials and parses the token pair', () async {
    respond = () => {
      'success': true,
      'message': 'ok',
      'data': {'access_token': 'access-1', 'refresh_token': 'refresh-1', 'token_type': 'bearer'},
    };

    final tokens = await dataSource.login(
      email: 'owner@example.com',
      password: 'secret1234',
      rememberMe: true,
      deviceId: 'device-1',
      deviceName: 'Test Device',
    );

    expect(tokens.accessToken, 'access-1');
    expect(tokens.refreshToken, 'refresh-1');
    expect(lastMethod, 'POST');
    expect(lastPath, '/api/v1/auth/login');
    expect(lastRequestBody!['email'], 'owner@example.com');
    expect(lastRequestBody!['remember_me'], true);
    expect(lastRequestBody!['device_id'], 'device-1');
  });

  test('logout posts the refresh token', () async {
    await dataSource.logout('refresh-1');

    expect(lastPath, '/api/v1/auth/logout');
    expect(lastRequestBody!['refresh_token'], 'refresh-1');
  });

  test('me parses the current user envelope', () async {
    respond = () => {
      'success': true,
      'message': 'ok',
      'data': {
        'user_id': 'user-1',
        'company_id': 'company-1',
        'branch_id': 'branch-1',
        'email': 'owner@example.com',
        'full_name': 'Ada Owner',
        'permissions': ['company.read', 'dashboard.read'],
      },
    };

    final user = await dataSource.me();

    expect(user.userId, 'user-1');
    expect(user.branchId, 'branch-1');
    expect(user.permissions, ['company.read', 'dashboard.read']);
  });

  test('forgotPassword posts the email', () async {
    await dataSource.forgotPassword('owner@example.com');

    expect(lastPath, '/api/v1/auth/forgot-password');
    expect(lastRequestBody!['email'], 'owner@example.com');
  });

  test('resetPassword posts the token and new password', () async {
    await dataSource.resetPassword(token: 'reset-tok', newPassword: 'new-pass-123');

    expect(lastRequestBody!['token'], 'reset-tok');
    expect(lastRequestBody!['new_password'], 'new-pass-123');
  });

  test('changePassword posts both passwords', () async {
    await dataSource.changePassword(currentPassword: 'old', newPassword: 'new-pass-123');

    expect(lastRequestBody!['current_password'], 'old');
    expect(lastRequestBody!['new_password'], 'new-pass-123');
  });

  test('myBranches parses the branch list', () async {
    respond = () => {
      'success': true,
      'message': 'ok',
      'data': [
        {'id': 'b1', 'name': 'Head Office', 'code': 'HO'},
      ],
    };

    final branches = await dataSource.myBranches();

    expect(branches, hasLength(1));
    expect(branches.first.name, 'Head Office');
  });

  test('switchBranch posts the target branch and returns the new access token', () async {
    respond = () => {
      'success': true,
      'message': 'ok',
      'data': {'access_token': 'new-access-token'},
    };

    final token = await dataSource.switchBranch('branch-2');

    expect(token, 'new-access-token');
    expect(lastRequestBody!['branch_id'], 'branch-2');
  });

  test('a 401 response surfaces as a DioException', () async {
    await server.close(force: true);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = 401;
      await request.response.close();
    });
    dio = Dio(BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'));
    dataSource = AuthRemoteDataSource(dio);

    expect(
      () => dataSource.login(email: 'x@example.com', password: 'wrong', rememberMe: false),
      throwsA(isA<DioException>()),
    );
  });
}
