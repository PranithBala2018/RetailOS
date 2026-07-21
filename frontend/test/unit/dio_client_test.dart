import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/core/config/app_config.dart';
import 'package:retailos/core/network/auth_interceptor.dart';
import 'package:retailos/core/network/dio_client.dart';
import 'package:retailos/core/network/request_logging_interceptor.dart';
import 'package:retailos/core/network/token_storage.dart';

void main() {
  test('createDioClient targets the configured API host', () {
    final dio = createDioClient(tokenStorage: TokenStorage(storage: const FlutterSecureStorage()));

    expect(dio.options.baseUrl, AppConfig.apiHost);
    expect(dio.options.contentType, 'application/json');
  });

  test('createDioClient installs logging before auth in the interceptor chain', () {
    final dio = createDioClient(tokenStorage: TokenStorage(storage: const FlutterSecureStorage()));

    final loggingIndex = dio.interceptors.indexWhere((i) => i is RequestLoggingInterceptor);
    final authIndex = dio.interceptors.indexWhere((i) => i is AuthInterceptor);

    expect(loggingIndex, isNonNegative);
    expect(authIndex, isNonNegative);
    expect(loggingIndex, lessThan(authIndex));
  });
}
