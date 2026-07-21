import 'package:dio/dio.dart';

import 'token_storage.dart';

/// Attaches the bearer access token to every outgoing request.
///
/// Refresh-on-401 is the seam left for Sprint 2: once the Identity module
/// exposes `POST /auth/refresh`, a `RequestRetrier` callback gets passed
/// in here to retry the failed request after rotating the token. Until
/// then, a 401 is simply passed through — there is no token to refresh
/// against yet.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenStorage);

  final TokenStorage _tokenStorage;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokenStorage.readAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
