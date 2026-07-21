import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retailos/core/network/auth_interceptor.dart';
import 'package:retailos/core/network/token_storage.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late HttpServer server;
  late Dio dio;
  late _MockSecureStorage secureStorage;
  Map<String, String>? capturedHeaders;

  setUp(() async {
    secureStorage = _MockSecureStorage();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      capturedHeaders = {
        for (final key
            in request.headers.value('authorization') != null ? ['authorization'] : <String>[])
          key: request.headers.value(key)!,
      };
      await request.response.close();
    });

    dio = Dio(BaseOptions(baseUrl: 'http://${server.address.host}:${server.port}'))
      ..interceptors.add(AuthInterceptor(TokenStorage(storage: secureStorage)));
  });

  tearDown(() async {
    await server.close(force: true);
    dio.close();
  });

  test('attaches the bearer token when one is stored', () async {
    when(
      () => secureStorage.read(key: 'retailos.auth.access_token'),
    ).thenAnswer((_) async => 'stored-access-token');

    await dio.get<void>('/ping');

    expect(capturedHeaders?['authorization'], 'Bearer stored-access-token');
  });

  test('sends no Authorization header when no token is stored', () async {
    when(() => secureStorage.read(key: 'retailos.auth.access_token')).thenAnswer((_) async => null);

    await dio.get<void>('/ping');

    expect(capturedHeaders?['authorization'], isNull);
  });
}
