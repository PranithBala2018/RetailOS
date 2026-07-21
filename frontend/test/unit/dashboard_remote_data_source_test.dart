import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/features/dashboard/data/datasources/dashboard_remote_data_source.dart';

void main() {
  late HttpServer server;
  late Dio dio;
  late DashboardRemoteDataSource dataSource;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dio = Dio(BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'));
    dataSource = DashboardRemoteDataSource(dio);
  });

  tearDown(() async {
    await server.close(force: true);
    dio.close();
  });

  test('parses the dashboard shell envelope', () async {
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'success': true,
          'message': 'ok',
          'data': {
            'company_name': 'Acme Retail',
            'branch_name': 'Head Office',
            'user_full_name': 'Ada Owner',
            'role_names': ['Super Admin'],
            'api_status': 'ok',
            'database_status': 'ok',
            'api_version': '0.1.0',
          },
        }),
      );
      await request.response.close();
    });

    final shell = await dataSource.fetchShell();

    expect(shell.companyName, 'Acme Retail');
    expect(shell.branchName, 'Head Office');
    expect(shell.roleNames, ['Super Admin']);
  });

  test('handles a null branch name', () async {
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'success': true,
          'message': 'ok',
          'data': {
            'company_name': 'Acme Retail',
            'branch_name': null,
            'user_full_name': 'Ada Owner',
            'role_names': <String>[],
            'api_status': 'ok',
            'database_status': 'ok',
            'api_version': '0.1.0',
          },
        }),
      );
      await request.response.close();
    });

    final shell = await dataSource.fetchShell();

    expect(shell.branchName, isNull);
  });
}
