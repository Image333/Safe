import 'package:shared_preferences/shared_preferences.dart';

import '../storage/auth_storage.dart';
import '../storage/camouflage_storage.dart';
import '../storage/secret_pin_storage.dart';
import '../storage/trusted_contacts_storage.dart';
import '../storage/voice_trigger_storage.dart';
import 'app_camouflage_service.dart';
import 'voice_trigger_service.dart';

class AppResetService {
  final SecretPinStorage _pinStorage;
  final CamouflageStorage _camouflageStorage;
  final AppCamouflageService _camouflageService;
  final VoiceTriggerService _voiceTriggerService;
  final VoiceTriggerStorage _voiceTriggerStorage;
  final TrustedContactsStorage _contactsStorage;
  final AuthStorage _authStorage;

  AppResetService({
    SecretPinStorage? pinStorage,
    CamouflageStorage? camouflageStorage,
    AppCamouflageService? camouflageService,
    VoiceTriggerService? voiceTriggerService,
    VoiceTriggerStorage? voiceTriggerStorage,
    TrustedContactsStorage? contactsStorage,
    AuthStorage? authStorage,
  })  : _pinStorage = pinStorage ?? SecretPinStorage(),
        _camouflageStorage = camouflageStorage ?? CamouflageStorage(),
        _camouflageService = camouflageService ?? AppCamouflageService(),
        _voiceTriggerService = voiceTriggerService ?? VoiceTriggerService(),
        _voiceTriggerStorage = voiceTriggerStorage ?? VoiceTriggerStorage(),
        _contactsStorage = contactsStorage ?? TrustedContactsStorage(),
        _authStorage = authStorage ?? AuthStorage();

  Future<void> resetAll() async {
    await _voiceTriggerService.disarm();
    await _voiceTriggerStorage.clear();
    await _contactsStorage.clear();
    await _authStorage.clear();
    await _pinStorage.clearAll();
    await _camouflageStorage.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _camouflageService.disableCalculatorCamouflage();
  }
}
