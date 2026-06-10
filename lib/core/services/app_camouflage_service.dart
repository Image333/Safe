import 'dart:io';

import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';

import '../storage/camouflage_storage.dart';

class AppCamouflageService {
  static const _iosAlternateIconName = 'calculator';

  final CamouflageStorage _storage;

  AppCamouflageService({CamouflageStorage? storage})
      : _storage = storage ?? CamouflageStorage();

  Future<void> enableCalculatorCamouflage() async {
    await _storage.enableCalculatorCamouflage();
    await _applyIosCalculatorIcon();
  }

  Future<void> ensureCalculatorCamouflageApplied() async {
    if (!await _storage.isCalculatorCamouflageEnabled()) return;
    await _applyIosCalculatorIcon();
  }

  Future<void> disableCalculatorCamouflage() async {
    await _storage.disableCalculatorCamouflage();
    if (!Platform.isIOS) return;

    try {
      final supports = await FlutterDynamicIcon.supportsAlternateIcons;
      if (supports) {
        await FlutterDynamicIcon.setAlternateIconName(null);
      }
    } catch (_) {}
  }

  Future<void> _applyIosCalculatorIcon() async {
    if (!Platform.isIOS) return;

    try {
      final supports = await FlutterDynamicIcon.supportsAlternateIcons;
      if (!supports) return;

      final current = await FlutterDynamicIcon.getAlternateIconName();
      if (current == _iosAlternateIconName) return;

      await FlutterDynamicIcon.setAlternateIconName(_iosAlternateIconName);
    } catch (_) {}
  }
}
