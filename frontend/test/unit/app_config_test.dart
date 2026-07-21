import 'package:flutter_test/flutter_test.dart';
import 'package:retailos/core/config/app_config.dart';

void main() {
  test('apiHost defaults to localhost when no --dart-define is supplied', () {
    expect(AppConfig.apiHost, 'http://localhost:8000');
  });

  test('apiV1Prefix matches the backend API_V1_PREFIX default', () {
    expect(AppConfig.apiV1Prefix, '/api/v1');
  });

  test('isProduction reflects the dart.vm.product flag', () {
    expect(AppConfig.isProduction, isFalse);
  });
}
