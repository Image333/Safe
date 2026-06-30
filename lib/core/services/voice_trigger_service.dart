import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../storage/voice_trigger_storage.dart';

enum VoiceTriggerState {
  stopped,
  listening,
  recording,
}

class VoiceTriggerConfig {
  final bool armed;
  final String? keyword;
  final int recordingDurationSec;

  const VoiceTriggerConfig({
    required this.armed,
    required this.keyword,
    required this.recordingDurationSec,
  });
}

class VoiceTriggerService {
  static const MethodChannel _channel =
      MethodChannel('safe/voice_trigger');

  static const int defaultRecordingDurationSec =
    VoiceTriggerStorage.defaultRecordingDurationSec;
  static const int minRecordingDurationSec =
    VoiceTriggerStorage.minRecordingDurationSec;
  static const int maxRecordingDurationSec =
    VoiceTriggerStorage.maxRecordingDurationSec;

  final VoiceTriggerStorage _storage;

  VoiceTriggerService({VoiceTriggerStorage? storage})
      : _storage = storage ?? VoiceTriggerStorage();

  Future<VoiceTriggerConfig> getConfig() async {
    final armed = await _storage.isArmed();
    final keyword = await _storage.getKeyword();
    final recordingDurationSec = await _storage.getRecordingDurationSec();

    return VoiceTriggerConfig(
      armed: armed,
      keyword: keyword,
      recordingDurationSec: recordingDurationSec,
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

    await _channel.invokeMethod<void>('startListening', {
      'keyword': keyword,
      'recordingDurationSec': recordingDurationSec,
    });
  }

  Future<void> disarm() async {
    await _storage.setArmed(false);
    await _channel.invokeMethod<void>('stopListening');
  }

  Future<void> syncStateAtAppStart() async {
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

    await _channel.invokeMethod<void>('startListening', {
      'keyword': keyword,
      'recordingDurationSec': recordingDurationSec,
    });
  }
}
