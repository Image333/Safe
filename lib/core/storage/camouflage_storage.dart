import 'package:shared_preferences/shared_preferences.dart';

class CamouflageStorage {
  static const _enabledKey = 'calculator_camouflage_enabled';

  Future<bool> isCalculatorCamouflageEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> enableCalculatorCamouflage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
  }

  Future<void> disableCalculatorCamouflage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_enabledKey);
  }
}
