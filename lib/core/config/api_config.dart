/// Configuration de l'API backend Safe et du stockage MinIO.
///
/// Surcharge possible au build :
/// ```
/// flutter run \
///   --dart-define=API_HOST=... \
///   --dart-define=API_PORT=... \
///   --dart-define=API_KEY_APP=... \
///   --dart-define=MINIO_HOST=... \
///   --dart-define=MINIO_PORT=... \
///   --dart-define=MINIO_BUCKET=... \
///   --dart-define=MINIO_ACCESS_KEY=... \
///   --dart-define=MINIO_SECRET_KEY=... \
///   --dart-define=STUB_ALERT_ID=1
/// ```
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

  // ── MinIO (API S3 NodePort 30900, pas la console 30901) ───────────────────

  static const String minioHost = String.fromEnvironment(
    'MINIO_HOST',
    defaultValue: '82.65.130.61',
  );

  static const int minioPort = int.fromEnvironment(
    'MINIO_PORT',
    defaultValue: 30900,
  );

  static const String minioBucket = String.fromEnvironment(
    'MINIO_BUCKET',
    defaultValue: 'audio-bucket',
  );

  static const String minioAccessKey = String.fromEnvironment(
    'MINIO_ACCESS_KEY',
    defaultValue: 'minioadmin',
  );

  static const String minioSecretKey = String.fromEnvironment(
    'MINIO_SECRET_KEY',
    defaultValue: '4AuSP1OSI75lMJ9NC5owv31X8GptuPuT',
  );

  static String get minioPublicBaseUrl =>
      'http://$minioHost:$minioPort/$minioBucket';

  /// TODO: remplacer par l'ID renvoyé par POST /alerts quand la route existera.
  static const int stubAlertId = int.fromEnvironment(
    'STUB_ALERT_ID',
    defaultValue: 1,
  );

  /// Réécrit une URL cluster MinIO (`minio-service:9000`) vers l'URL publique.
  static String toPublicBlobUrl(String blobUrl) {
    var url = blobUrl;
    url = url.replaceFirst('http://minio-service:9000', 'http://$minioHost:$minioPort');
    url = url.replaceFirst('http://minio:9000', 'http://$minioHost:$minioPort');
    return url;
  }
}
