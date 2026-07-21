import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/core/config/app_config.dart';
import 'package:retailos/core/di/providers.dart';
import 'package:retailos/core/network/auth_interceptor.dart';
import 'package:retailos/core/network/request_logging_interceptor.dart';
import 'package:retailos/core/network/token_storage.dart';

void main() {
  test('tokenStorageProvider yields a TokenStorage singleton', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final a = container.read(tokenStorageProvider);
    final b = container.read(tokenStorageProvider);

    expect(a, isA<TokenStorage>());
    expect(identical(a, b), isTrue);
  });

  test('dioProvider configures the API host as the base URL', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);

    expect(dio.options.baseUrl, AppConfig.apiHost);
  });

  test('dioProvider wires the request-logging and auth interceptors', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);

    expect(dio.interceptors.whereType<RequestLoggingInterceptor>(), hasLength(1));
    expect(dio.interceptors.whereType<AuthInterceptor>(), hasLength(1));
  });
}
