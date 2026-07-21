import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/core/network/request_logging_interceptor.dart';

void main() {
  late HttpServer server;
  late Dio dio;
  String? capturedRequestId;
  var responseStatusCode = 200;

  setUp(() async {
    responseStatusCode = 200;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      capturedRequestId = request.headers.value(requestIdHeader);
      request.response.statusCode = responseStatusCode;
      await request.response.close();
    });

    dio = Dio(BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'))
      ..interceptors.add(RequestLoggingInterceptor());
  });

  tearDown(() async {
    await server.close(force: true);
    dio.close();
  });

  test('stamps every outgoing request with a unique X-Request-ID', () async {
    await dio.get<void>('/ping');
    final first = capturedRequestId;

    await dio.get<void>('/ping');
    final second = capturedRequestId;

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first, isNot(equals(second)));
  });

  test('a 5xx response still surfaces as a DioException to the caller', () async {
    responseStatusCode = 500;

    expect(() => dio.get<void>('/ping'), throwsA(isA<DioException>()));
  });
}
