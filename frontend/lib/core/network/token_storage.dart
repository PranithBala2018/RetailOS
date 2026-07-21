import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted-at-rest storage for JWT access/refresh tokens, per
/// SPRINT0.md §16 (Android Keystore / Windows DPAPI-backed).
///
/// This is JWT infrastructure only — nothing here knows about a `User` or
/// calls a login endpoint. That lands with the Identity module in Sprint 2.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'retailos.auth.access_token';
  static const _refreshTokenKey = 'retailos.auth.refresh_token';

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
