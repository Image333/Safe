import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../storage/voice_trigger_storage.dart';
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

  static const int defaultRecordingDurationSec =
      VoiceTriggerStorage.defaultRecordingDurationSec;
  static const int minRecordingDurationSec =
      VoiceTriggerStorage.minRecordingDurationSec;
  static const int maxRecordingDurationSec =
      VoiceTriggerStorage.maxRecordingDurationSec;

  final VoiceTriggerStorage _storage;
  final SpeechRecognitionService _speechService;

  VoiceTriggerService({VoiceTriggerStorage? storage})
      : _storage = storage ?? VoiceTriggerStorage(),
        _speechService = SpeechRecognitionService();

  /// Accès au service de reconnaissance vocale
  SpeechRecognitionService get speechService => _speechService;

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

    await _storage.setArmed(true);

    // Démarrer le service de maintien en arrière-plan pour iOS
    if (Platform.isIOS) {
      await BackgroundKeepAliveService.instance.start();
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
      // Utiliser le canal natif iOS avec timeout pour éviter le blocage
      await _channel.invokeMethod('startListening', {
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
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ iOS: Timeout écoute native, utilisation du fallback');
          return null;
        },
      );
      debugPrint('🎤 iOS: Écoute native démarrée via VoiceTriggerManager');
    } catch (e) {
      debugPrint('❌ iOS: Erreur écoute native: $e');
      // Fallback sur speech_to_text Flutter (moins fiable en background)
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
