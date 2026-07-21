import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/features/bootstrap/data/datasources/health_remote_data_source.dart';

void main() {
  late HttpServer server;
  late Dio dio;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dio = Dio(BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'));
  });

  tearDown(() async {
    await server.close(force: true);
    dio.close();
  });

  test('parses the API envelope into an ApiHealth entity', () async {
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'success': true,
          'message': 'ok',
          'data': {'status': 'ok', 'environment': 'testing'},
        }),
      );
      await request.response.close();
    });

    final health = await HealthRemoteDataSource(dio).fetchHealth();

    expect(health.status, 'ok');
    expect(health.environment, 'testing');
  });

  test('propagates a DioException when the server returns a 5xx', () async {
    server.listen((request) async {
      request.response.statusCode = 503;
      await request.response.close();
    });

    expect(() => HealthRemoteDataSource(dio).fetchHealth(), throwsA(isA<DioException>()));
  });
}
