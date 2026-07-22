/// Configuration de l'API backend Safe.
///
/// Surcharge possible au build :
/// `flutter run --dart-define=API_HOST=... --dart-define=API_PORT=... --dart-define=API_KEY_APP=...`
class ApiConfig {
  static const String host = String.fromEnvironment(
    'API_HOST',
    defaultValue: '82.65.130.61',
  );

  static const String port = String.fromEnvironment(
    'API_PORT',
    defaultValue: '30001',
  );

  /// Clé API applicative (header `X-API-Key`)
  static const String apiKeyApp = String.fromEnvironment(
    'API_KEY_APP',
    defaultValue: 'GpeApp-7xK9mP2vL5nQ8wR3tY6uJ1fC4hB9aD0e',
  );

  static const String apiPrefix = '/api/v1';

  static String get baseUrl => 'http://$host:$port$apiPrefix';
}
