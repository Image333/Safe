import 'package:shared_preferences/shared_preferences.dart';

import '../storage/camouflage_storage.dart';
import '../storage/secret_pin_storage.dart';
import 'app_camouflage_service.dart';

class AppResetService {
  final SecretPinStorage _pinStorage;
  final CamouflageStorage _camouflageStorage;
  final AppCamouflageService _camouflageService;

  AppResetService({
    SecretPinStorage? pinStorage,
    CamouflageStorage? camouflageStorage,
    AppCamouflageService? camouflageService,
  })  : _pinStorage = pinStorage ?? SecretPinStorage(),
        _camouflageStorage = camouflageStorage ?? CamouflageStorage(),
        _camouflageService = camouflageService ?? AppCamouflageService();

  Future<void> resetAll() async {
    await _pinStorage.clearAll();
    await _camouflageStorage.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _camouflageService.disableCalculatorCamouflage();
  }
}
