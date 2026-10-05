import 'package:shared_preferences/shared_preferences.dart';

import '../storage/camouflage_storage.dart';
import '../storage/secret_pin_storage.dart';
import '../storage/voice_trigger_storage.dart';
import 'app_camouflage_service.dart';
import 'voice_trigger_service.dart';

class AppResetService {
  final SecretPinStorage _pinStorage;
  final CamouflageStorage _camouflageStorage;
  final AppCamouflageService _camouflageService;
  final VoiceTriggerService _voiceTriggerService;
  final VoiceTriggerStorage _voiceTriggerStorage;

  AppResetService({
    SecretPinStorage? pinStorage,
    CamouflageStorage? camouflageStorage,
    AppCamouflageService? camouflageService,
    VoiceTriggerService? voiceTriggerService,
    VoiceTriggerStorage? voiceTriggerStorage,
  })  : _pinStorage = pinStorage ?? SecretPinStorage(),
        _camouflageStorage = camouflageStorage ?? CamouflageStorage(),
      _camouflageService = camouflageService ?? AppCamouflageService(),
        _voiceTriggerService = voiceTriggerService ?? VoiceTriggerService(),
        _voiceTriggerStorage = voiceTriggerStorage ?? VoiceTriggerStorage();

  Future<void> resetAll() async {
    await _voiceTriggerService.disarm();
    await _voiceTriggerStorage.clear();
    await _pinStorage.clearAll();
    await _camouflageStorage.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _camouflageService.disableCalculatorCamouflage();
  }
}
