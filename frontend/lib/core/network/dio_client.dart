import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'auth_interceptor.dart';
import 'request_logging_interceptor.dart';
import 'token_storage.dart';

/// Builds the single Dio instance the app talks to the API through.
///
/// Interceptor order matters: request id + logging wraps the outermost so
/// every attempt (including retries added in later sprints) is observable,
/// auth runs innermost so it decorates the final request right before send.
Dio createDioClient({required TokenStorage tokenStorage}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiHost,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
    ),
  );

  dio.interceptors.addAll([RequestLoggingInterceptor(), AuthInterceptor(tokenStorage)]);

  return dio;
}
