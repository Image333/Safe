import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../storage/auth_storage.dart';
import '../storage/voice_trigger_storage.dart';
import 'api_service.dart';
import 'audio_history_service.dart';
import 'audio_sync_service.dart';
import 'speech_recognition_service.dart';
import 'background_keep_alive_service.dart';

enum VoiceTriggerState {
  stopped,
  listening,
  recording,
}

class VoiceTriggerSchedule {
  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final List<int> days; // 0 = Dimanche, 1 = Lundi, ..., 6 = Samedi

  const VoiceTriggerSchedule({
    required this.enabled,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.days,
  });

  String get formattedStartTime => '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
  String get formattedEndTime => '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
}

class VoiceTriggerConfig {
  final bool armed;
  final String? keyword;
  final int recordingDurationSec;
  final VoiceTriggerSchedule? schedule;

  const VoiceTriggerConfig({
    required this.armed,
    required this.keyword,
    required this.recordingDurationSec,
    this.schedule,
  });
}

class VoiceTriggerService {
  static const MethodChannel _channel = MethodChannel('safe/voice_trigger');
  static const EventChannel _eventChannel =
      EventChannel('safe/voice_trigger_events');

  static const int defaultRecordingDurationSec =
      VoiceTriggerStorage.defaultRecordingDurationSec;
  static const int minRecordingDurationSec =
      VoiceTriggerStorage.minRecordingDurationSec;
  static const int maxRecordingDurationSec =
      VoiceTriggerStorage.maxRecordingDurationSec;

  final VoiceTriggerStorage _storage;
  final SpeechRecognitionService _speechService;
  final AudioSyncService _audioSyncService;
  final AudioHistoryService _audioHistoryService;
  final ApiService _apiService;
  final AuthStorage _authStorage;

  StreamSubscription<dynamic>? _eventSubscription;

  /// Callbacks optionnels pour que l'UI réagisse aux événements du moteur.
  void Function()? onKeywordDetected;
  void Function()? onRecordingStarted;
  void Function(String filePath, AudioSyncResult syncResult)? onRecordingSynced;
  void Function(String message)? onError;

  VoiceTriggerService({
    VoiceTriggerStorage? storage,
    AudioSyncService? audioSyncService,
    AudioHistoryService? audioHistoryService,
    ApiService? apiService,
    AuthStorage? authStorage,
  })  : _storage = storage ?? VoiceTriggerStorage(),
        _audioSyncService = audioSyncService ?? AudioSyncService(),
        _audioHistoryService = audioHistoryService ?? AudioHistoryService(),
        _apiService = apiService ?? ApiService(),
        _authStorage = authStorage ?? AuthStorage(),
        _speechService = SpeechRecognitionService() {
    _bindSpeechServiceCallbacks();
    _listenToNativeEvents();
  }

  /// Accès au service de reconnaissance vocale
  SpeechRecognitionService get speechService => _speechService;

  /// Écoute les événements remontés par le moteur natif iOS.
  void _listenToNativeEvents() {
    if (!Platform.isIOS) return;
    _eventSubscription ??= _eventChannel.receiveBroadcastStream().listen(
      _handleNativeEvent,
      onError: (Object e) => debugPrint('⚠️ VoiceTrigger event error: $e'),
    );
  }

  void _handleNativeEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['event'] as String?;
    switch (type) {
      case 'keyword_detected':
        debugPrint('🚨 VoiceTrigger: mot-clé détecté (natif)');
        onKeywordDetected?.call();
        break;
      case 'recording_started':
        debugPrint('🔴 VoiceTrigger: enregistrement démarré (natif)');
        onRecordingStarted?.call();
        break;
      case 'recording_completed':
        final filePath = event['filePath'] as String?;
        final durationSec = (event['durationSec'] as int?) ?? 0;
        if (filePath != null && filePath.isNotEmpty) {
          _syncRecordedClip(filePath, durationSec);
        }
        break;
      case 'error':
        final message = event['message'] as String? ?? 'Erreur inconnue';
        debugPrint('⚠️ VoiceTrigger error (natif): $message');
        onError?.call(message);
        break;
    }
  }

  /// Branche les callbacks du fallback Flutter (speech_to_text) pour que
  /// les clips enregistrés côté Dart soient aussi synchronisés.
  void _bindSpeechServiceCallbacks() {
    _speechService.onKeywordDetected = () => onKeywordDetected?.call();
    _speechService.onRecordingStarted = () => onRecordingStarted?.call();
    _speechService.onRecordingFinished = (path) {
      final durationSec = _speechService.recordingDurationSec;
      _syncRecordedClip(path, durationSec);
    };
    _speechService.onError = (error) => onError?.call(error);
  }

  /// Crée l'alerte (Telegram texte), puis upload MinIO + POST /alerts/:id/audio
  /// (le backend joint alors l'audio aux contacts Telegram).
  Future<void> _syncRecordedClip(String filePath, int durationSec) async {
    // Rendre le clip visible dans l'historique local (le moteur natif iOS écrit
    // dans Documents/emergency_*.m4a, hors du dossier lu par l'historique).
    final localPath = await _audioHistoryService.importExternalClip(filePath);
    try {
      final alertId = await _createAlertForVoiceTrigger();
      final result = await _audioSyncService.syncEmergencyClip(
        localFilePath: localPath,
        durationSec: durationSec > 0 ? durationSec : 1,
        alertId: alertId,
      );
      if (result.uploaded) {
        debugPrint(
          '☁️ VoiceTrigger: clip synchronisé'
          ' (alert_id=$alertId, audio_id=${result.audioId})',
        );
      } else {
        debugPrint('💾 VoiceTrigger: clip conservé en local'
            '${result.errorMessage != null ? " (${result.errorMessage})" : ""}');
      }
      onRecordingSynced?.call(localPath, result);
    } catch (e) {
      debugPrint('❌ VoiceTrigger: échec sync clip: $e');
      onError?.call('Échec de la synchronisation du clip: $e');
      onRecordingSynced?.call(localPath, AudioSyncResult.failed(e.toString()));
    }
  }

  /// Notifie les contacts via POST /alerts ; retourne l'alert_id ou null hors-ligne.
  Future<int?> _createAlertForVoiceTrigger() async {
    try {
      final token = await _authStorage.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('VoiceTrigger: pas de session — alerte Telegram ignorée');
        return null;
      }
      final alert = await _apiService.createAlert(token: token);
      debugPrint(
        '🚨 VoiceTrigger: alerte #${alert.alertId} créée'
        ' (${alert.sentCount} Telegram envoyé(s))',
      );
      return alert.alertId > 0 ? alert.alertId : null;
    } catch (e) {
      debugPrint('⚠️ VoiceTrigger: createAlert échoué: $e');
      return null;
    }
  }

  /// Libère les ressources (souscription EventChannel).
  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  Future<VoiceTriggerConfig> getConfig() async {
    final armed = await _storage.isArmed();
    final keyword = await _storage.getKeyword();
    final recordingDurationSec = await _storage.getRecordingDurationSec();

    // Charger la configuration de plage horaire
    final scheduleEnabled = await _storage.isScheduleEnabled();
    final startHour = await _storage.getScheduleStartHour();
    final startMinute = await _storage.getScheduleStartMinute();
    final endHour = await _storage.getScheduleEndHour();
    final endMinute = await _storage.getScheduleEndMinute();
    final days = await _storage.getScheduleDays();

    return VoiceTriggerConfig(
      armed: armed,
      keyword: keyword,
      recordingDurationSec: recordingDurationSec,
      schedule: VoiceTriggerSchedule(
        enabled: scheduleEnabled,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
        days: days,
      ),
    );
  }

  Future<void> saveConfig({
    required String keyword,
    int recordingDurationSec = defaultRecordingDurationSec,
  }) async {
    final safeDuration = recordingDurationSec
        .clamp(minRecordingDurationSec, maxRecordingDurationSec)
        .toInt();

    await _storage.setKeyword(keyword);
    await _storage.setRecordingDurationSec(safeDuration);
  }

  Future<void> saveSchedule({
    required bool enabled,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required List<int> days,
  }) async {
    await _storage.setScheduleEnabled(enabled);
    await _storage.setScheduleStartTime(startHour, startMinute);
    await _storage.setScheduleEndTime(endHour, endMinute);
    await _storage.setScheduleDays(days);
  }

  Future<bool> isCurrentTimeInSchedule() async {
    return await _storage.isCurrentTimeInSchedule();
  }

  Future<void> arm() async {
    final keyword = await _storage.getKeyword();
    final recordingDurationSec = await _storage.getRecordingDurationSec();

    if (keyword == null || keyword.trim().isEmpty) {
      throw StateError('Veuillez définir un mot-clé avant d\'armer le système.');
    }

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      throw StateError('Permission micro refusée. Activez-la dans les réglages.');
    }

    // iOS: la reconnaissance vocale native exige aussi l'autorisation Speech,
    // sinon startListening() échoue côté natif avant même d'activer le micro.
    if (Platform.isIOS) {
      final speechGranted = await requestSpeechPermission();
      if (!speechGranted) {
        throw StateError(
          'Permission reconnaissance vocale refusée. Activez-la dans les réglages.',
        );
      }
    }

    await _storage.setArmed(true);

    // Démarrer le service de maintien en arrière-plan pour iOS (non-bloquant)
    if (Platform.isIOS) {
      // Lancer en arrière-plan sans attendre
      BackgroundKeepAliveService.instance.start().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('⚠️ BackgroundKeepAlive timeout, ignoré');
        },
      ).catchError((e) {
        debugPrint('⚠️ BackgroundKeepAlive error: $e');
      });
    }

    if (Platform.isAndroid) {
      await _startAndroidForegroundService(keyword, recordingDurationSec);
    } else {
      await _startIosNativeListening(keyword, recordingDurationSec);
    }

    debugPrint('🎤 VoiceTrigger: Écoute activée pour "$keyword"');
  }

  Future<void> _startAndroidForegroundService(
      String keyword, int recordingDurationSec) async {
    try {
      await _channel.invokeMethod('startListening', {
        'keyword': keyword,
        'recordingDurationSec': recordingDurationSec,
      });
      debugPrint('🎤 Android Foreground Service démarré');
    } catch (e) {
      debugPrint('❌ Erreur Android Foreground Service: $e');
      // Fallback sur speech_to_text Flutter
      await _startIosListening(keyword, recordingDurationSec);
    }
  }

  Future<void> _startIosNativeListening(
      String keyword, int recordingDurationSec) async {
    debugPrint('🎤 iOS: Démarrage écoute native...');

    // Charger la configuration de plage horaire
    final scheduleEnabled = await _storage.isScheduleEnabled();
    final startHour = await _storage.getScheduleStartHour();
    final startMinute = await _storage.getScheduleStartMinute();
    final endHour = await _storage.getScheduleEndHour();
    final endMinute = await _storage.getScheduleEndMinute();
    final days = await _storage.getScheduleDays();

    try {
      // Utiliser le canal natif iOS avec timeout court
      final result = await _channel.invokeMethod('startListening', {
        'keyword': keyword,
        'recordingDurationSec': recordingDurationSec,
        'schedule': {
          'enabled': scheduleEnabled,
          'startHour': startHour,
          'startMinute': startMinute,
          'endHour': endHour,
          'endMinute': endMinute,
          'days': days,
        },
      }).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⚠️ iOS: Timeout écoute native (3s), passage au fallback Flutter');
          return 'timeout';
        },
      );
      
      if (result == 'timeout') {
        // Fallback sur Flutter speech_to_text
        await _startFlutterSpeechListening(keyword, recordingDurationSec);
      } else {
        debugPrint('🎤 iOS: Écoute native démarrée via VoiceTriggerManager');
      }
    } catch (e) {
      debugPrint('❌ iOS: Erreur écoute native: $e');
      // Fallback sur speech_to_text Flutter
      await _startFlutterSpeechListening(keyword, recordingDurationSec);
    }
  }

  /// Démarre l'écoute via le plugin Flutter speech_to_text
  Future<void> _startFlutterSpeechListening(
      String keyword, int recordingDurationSec) async {
    debugPrint('🎤 Fallback: Démarrage speech_to_text Flutter...');
    _speechService.configure(
      keyword: keyword,
      recordingDurationSec: recordingDurationSec,
    );
    await _speechService.startListening();
    debugPrint('🎤 Fallback: speech_to_text Flutter activé');
  }

  // Garder l'ancienne méthode pour compatibilité/fallback
  Future<void> _startIosListening(
      String keyword, int recordingDurationSec) async {
    debugPrint('🎤 iOS: Configuration du speech service...');

    // Configurer la reconnaissance vocale
    _speechService.configure(
      keyword: keyword,
      recordingDurationSec: recordingDurationSec,
    );

    debugPrint('🎤 iOS: Démarrage de l\'écoute...');
    await _speechService.startListening();
    debugPrint('🎤 iOS: speech_to_text activé');
  }

  Future<void> disarm() async {
    await _storage.setArmed(false);

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('stopListening');
      } catch (e) {
        debugPrint('❌ Erreur arrêt Android service: $e');
      }
    }

    // Arrêter dans tous les cas
    await _speechService.stopListening();
    await BackgroundKeepAliveService.instance.stop();

    debugPrint('🎤 VoiceTrigger: Désarmé');
  }

  Future<void> syncStateAtAppStart() async {
    try {
      final armed = await _storage.isArmed();
      if (!armed) return;

      final keyword = await _storage.getKeyword();
      final recordingDurationSec = await _storage.getRecordingDurationSec();

      if (keyword == null || keyword.trim().isEmpty) {
        await _storage.setArmed(false);
        return;
      }

      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        await _storage.setArmed(false);
        return;
      }

      // iOS: sans autorisation Speech, l'écoute native ne démarre pas.
      if (Platform.isIOS) {
        final speechGranted = await checkSpeechPermission();
        if (!speechGranted) {
          debugPrint('⚠️ Speech non autorisé au démarrage, désarmement');
          await _storage.setArmed(false);
          return;
        }
      }

      // Réarmer selon la plateforme (avec gestion d'erreur)
      if (Platform.isIOS) {
        try {
          await BackgroundKeepAliveService.instance.start();
        } catch (e) {
          debugPrint('⚠️ BackgroundKeepAlive start error: $e');
        }
      }
      
      if (Platform.isAndroid) {
        await _startAndroidForegroundService(keyword, recordingDurationSec);
      } else {
        await _startIosNativeListening(keyword, recordingDurationSec);
      }

      debugPrint('🎤 VoiceTrigger: Réarmé au démarrage');
    } catch (e) {
      debugPrint('❌ syncStateAtAppStart error: $e');
      // Ne pas propager l'erreur pour éviter de bloquer l'app
    }
  }

  /// Initialise le service de reconnaissance vocale
  Future<bool> initializeSpeechRecognition() async {
    return await _speechService.initialize();
  }

  /// Vérifie si la reconnaissance vocale est initialisée
  bool get isSpeechReady => _speechService.isInitialized;

  /// Vérifie si l'écoute native iOS est active
  Future<bool> isNativeListening() async {
    try {
      final result = await _channel.invokeMethod<bool>('isListening');
      debugPrint('🔍 isNativeListening: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ isNativeListening error: $e');
      return false;
    }
  }

  /// Vérifie si le micro capte réellement (tap installé), par opposition
  /// à `isNativeListening` qui reste vrai même hors plage horaire.
  Future<bool> isNativeActivelyListening() async {
    try {
      final result = await _channel.invokeMethod<bool>('isActivelyListening');
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ isNativeActivelyListening error: $e');
      return false;
    }
  }

  /// Vérifie si l'écoute native iOS est en enregistrement
  Future<bool> isNativeRecording() async {
    try {
      final result = await _channel.invokeMethod<bool>('isRecording');
      debugPrint('🔍 isNativeRecording: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ isNativeRecording error: $e');
      return false;
    }
  }

  /// Demande la permission de reconnaissance vocale (iOS)
  Future<bool> requestSpeechPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('requestSpeechPermission');
      return result ?? false;
    } catch (e) {
      // Fallback: initialiser speech_to_text (demande la permission)
      return await _speechService.initialize();
    }
  }

  /// Vérifie si la permission de reconnaissance vocale est accordée (iOS)
  Future<bool> checkSpeechPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('checkSpeechPermission');
      return result ?? false;
    } catch (e) {
      return _speechService.isInitialized;
    }
  }
}
