import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../utils/app_logger.dart';

const requestIdHeader = 'X-Request-ID';

/// Stamps every outgoing request with a correlation id (matching the
/// backend's request-id middleware, see SPRINT0.md §12) and logs
/// method/path/status without ever logging headers or bodies — those may
/// carry tokens or PII.
class RequestLoggingInterceptor extends Interceptor {
  final _logger = AppLogger('http');
  final _uuid = const Uuid();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[requestIdHeader] = _uuid.v4();
    _logger.debug('-> ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _logger.debug('<- ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.warning(
      '<- ${err.response?.statusCode ?? 'ERR'} ${err.requestOptions.path}: ${err.message}',
    );
    handler.next(err);
  }
}
