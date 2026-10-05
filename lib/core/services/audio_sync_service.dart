import '../config/api_config.dart';
import '../storage/auth_storage.dart';
import 'api_service.dart';
import 'minio_upload_service.dart';

/// Résultat d'une tentative de sync remote d'un clip.
class AudioSyncResult {
  final bool uploaded;
  final String? blobUrl;
  final int? audioId;
  final String? errorMessage;

  const AudioSyncResult({
    required this.uploaded,
    this.blobUrl,
    this.audioId,
    this.errorMessage,
  });

  factory AudioSyncResult.localOnly() => const AudioSyncResult(uploaded: false);

  factory AudioSyncResult.success({
    required String blobUrl,
    required int audioId,
  }) {
    return AudioSyncResult(
      uploaded: true,
      blobUrl: blobUrl,
      audioId: audioId,
    );
  }

  factory AudioSyncResult.failed(String message) {
    return AudioSyncResult(uploaded: false, errorMessage: message);
  }
}

/// Orchestre upload MinIO + metadata API pour un user connecté.
class AudioSyncService {
  final AuthServiceAware _auth;
  final ApiService _apiService;
  final MinioUploadService _minioUploadService;
  final AuthStorage _authStorage;

  AudioSyncService({
    AuthServiceAware? auth,
    ApiService? apiService,
    MinioUploadService? minioUploadService,
    AuthStorage? authStorage,
  })  : _auth = auth ?? const _DefaultAuthCheck(),
        _apiService = apiService ?? ApiService(),
        _minioUploadService = minioUploadService ?? MinioUploadService(),
        _authStorage = authStorage ?? AuthStorage();

  /// Si non authentifié → local only.
  /// Si authentifié → MinIO puis POST /alerts/:stubAlertId/audio.
  /// En cas d'échec → fallback local (fichier déjà sur disque).
  Future<AudioSyncResult> syncEmergencyClip({
    required String localFilePath,
    required int durationSec,
  }) async {
    final isAuthenticated = await _auth.isAuthenticated();
    if (!isAuthenticated) {
      return AudioSyncResult.localOnly();
    }

    try {
      final token = await _authStorage.getToken();
      if (token == null || token.isEmpty) {
        return AudioSyncResult.failed('Session expirée');
      }

      final userId = await _authStorage.getUserId() ?? 0;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final objectKey = '$userId/alert_$timestamp.m4a';

      final blobUrl = await _minioUploadService.uploadAudioFile(
        localFilePath: localFilePath,
        objectKey: objectKey,
      );

      // TODO: remplacer stubAlertId par l'ID renvoyé par POST /alerts
      final createResponse = await _apiService.createAudio(
        token: token,
        alertId: ApiConfig.stubAlertId,
        blobUrl: blobUrl,
        duration: durationSec > 0 ? durationSec : 1,
        format: 'm4a',
      );

      return AudioSyncResult.success(
        blobUrl: blobUrl,
        audioId: createResponse.audioId,
      );
    } on ApiException catch (e) {
      return AudioSyncResult.failed(e.message);
    } catch (e) {
      return AudioSyncResult.failed(e.toString());
    }
  }
}

/// Abstraction minimale pour tester / découpler AuthService.
abstract class AuthServiceAware {
  Future<bool> isAuthenticated();
}

class _DefaultAuthCheck implements AuthServiceAware {
  const _DefaultAuthCheck();

  @override
  Future<bool> isAuthenticated() => AuthStorage().hasToken();
}
