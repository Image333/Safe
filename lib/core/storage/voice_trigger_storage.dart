import 'package:shared_preferences/shared_preferences.dart';

class VoiceTriggerStorage {
  static const _armedKey = 'voice_trigger_armed';
  static const _keywordKey = 'voice_trigger_keyword';
  static const _recordingDurationSecKey = 'voice_trigger_recording_duration_sec';

  Future<bool> isArmed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_armedKey) ?? false;
  }

  Future<void> setArmed(bool armed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_armedKey, armed);
  }

  Future<String?> getKeyword() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keywordKey);
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  Future<void> setKeyword(String keyword) async {
    final normalized = keyword.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keywordKey, normalized);
  }

  Future<int> getRecordingDurationSec() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_recordingDurationSecKey) ?? 15;
  }

  Future<void> setRecordingDurationSec(int durationSec) async {
    final safeDuration = durationSec.clamp(5, 30).toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_recordingDurationSecKey, safeDuration);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_armedKey),
      prefs.remove(_keywordKey),
      prefs.remove(_recordingDurationSecKey),
    ]);
  }
}
