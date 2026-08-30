import 'package:shared_preferences/shared_preferences.dart';

class VoiceTriggerStorage {
  static const _armedKey = 'voice_trigger_armed';
  static const _keywordKey = 'voice_trigger_keyword';
  static const _recordingDurationSecKey = 'voice_trigger_recording_duration_sec';
  static const _scheduleEnabledKey = 'voice_trigger_schedule_enabled';
  static const _scheduleStartHourKey = 'voice_trigger_schedule_start_hour';
  static const _scheduleStartMinuteKey = 'voice_trigger_schedule_start_minute';
  static const _scheduleEndHourKey = 'voice_trigger_schedule_end_hour';
  static const _scheduleEndMinuteKey = 'voice_trigger_schedule_end_minute';
  static const _scheduleDaysKey = 'voice_trigger_schedule_days';

  static const int defaultRecordingDurationSec = 15;
  static const int minRecordingDurationSec = 5;
  static const int maxRecordingDurationSec = 600;

  // Plage horaire par défaut: 22h00 - 07h00 tous les jours
  static const int defaultStartHour = 22;
  static const int defaultStartMinute = 0;
  static const int defaultEndHour = 7;
  static const int defaultEndMinute = 0;
  static const List<int> defaultDays = [0, 1, 2, 3, 4, 5, 6]; // Tous les jours

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
    final stored = prefs.getInt(_recordingDurationSecKey);
    if (stored == null) return defaultRecordingDurationSec;
    return stored.clamp(minRecordingDurationSec, maxRecordingDurationSec).toInt();
  }

  Future<void> setRecordingDurationSec(int durationSec) async {
    final safeDuration = durationSec
        .clamp(minRecordingDurationSec, maxRecordingDurationSec)
        .toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_recordingDurationSecKey, safeDuration);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_armedKey),
      prefs.remove(_keywordKey),
      prefs.remove(_recordingDurationSecKey),
      prefs.remove(_scheduleEnabledKey),
      prefs.remove(_scheduleStartHourKey),
      prefs.remove(_scheduleStartMinuteKey),
      prefs.remove(_scheduleEndHourKey),
      prefs.remove(_scheduleEndMinuteKey),
      prefs.remove(_scheduleDaysKey),
    ]);
  }

  // ── Plage horaire ─────────────────────────────────────────────────────────

  Future<bool> isScheduleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scheduleEnabledKey) ?? false;
  }

  Future<void> setScheduleEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scheduleEnabledKey, enabled);
  }

  Future<int> getScheduleStartHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scheduleStartHourKey) ?? defaultStartHour;
  }

  Future<int> getScheduleStartMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scheduleStartMinuteKey) ?? defaultStartMinute;
  }

  Future<int> getScheduleEndHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scheduleEndHourKey) ?? defaultEndHour;
  }

  Future<int> getScheduleEndMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scheduleEndMinuteKey) ?? defaultEndMinute;
  }

  Future<void> setScheduleStartTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scheduleStartHourKey, hour.clamp(0, 23));
    await prefs.setInt(_scheduleStartMinuteKey, minute.clamp(0, 59));
  }

  Future<void> setScheduleEndTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scheduleEndHourKey, hour.clamp(0, 23));
    await prefs.setInt(_scheduleEndMinuteKey, minute.clamp(0, 59));
  }

  Future<List<int>> getScheduleDays() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_scheduleDaysKey);
    if (stored == null || stored.isEmpty) return List.from(defaultDays);
    return stored.map((e) => int.tryParse(e) ?? 0).toList();
  }

  Future<void> setScheduleDays(List<int> days) async {
    final prefs = await SharedPreferences.getInstance();
    final validDays = days.where((d) => d >= 0 && d <= 6).toList();
    await prefs.setStringList(_scheduleDaysKey, validDays.map((d) => d.toString()).toList());
  }

  /// Vérifie si l'heure actuelle est dans la plage horaire configurée
  Future<bool> isCurrentTimeInSchedule() async {
    final isEnabled = await isScheduleEnabled();
    if (!isEnabled) return true; // Si pas de plage, toujours actif

    final now = DateTime.now();
    // DateTime.weekday: 1=Lundi, 7=Dimanche
    // Notre système: 0=Dimanche, 1=Lundi, ..., 6=Samedi
    final currentDay = now.weekday == 7 ? 0 : now.weekday;
    
    // Vérifier si le jour actuel est sélectionné
    final days = await getScheduleDays();
    if (!days.contains(currentDay)) return false;

    final startHour = await getScheduleStartHour();
    final startMinute = await getScheduleStartMinute();
    final endHour = await getScheduleEndHour();
    final endMinute = await getScheduleEndMinute();

    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    // Gérer le cas où la plage traverse minuit (ex: 22h00 - 07h00)
    if (startMinutes > endMinutes) {
      // Plage qui traverse minuit
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    } else {
      // Plage normale (ex: 09h00 - 18h00)
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    }
  }
}
