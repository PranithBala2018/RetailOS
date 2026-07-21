/// Build-time configuration, sourced from `--dart-define` flags.
///
/// Kept dependency-free (no envied/flutter_dotenv) for Sprint 1 — there is
/// exactly one configurable value so far. Revisit if the list grows enough
/// that compile-time codegen starts paying for itself.
class AppConfig {
  const AppConfig._();

  /// Host root — Dio's `baseUrl`. Unversioned infra endpoints (`/health`)
  /// hang directly off this; versioned business endpoints use [apiV1Prefix].
  static const String apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'http://localhost:8000',
  );

  static const String apiV1Prefix = '/api/v1';

  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
}
