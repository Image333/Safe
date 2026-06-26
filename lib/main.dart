import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/services/app_camouflage_service.dart';
import 'core/services/voice_trigger_service.dart';
import 'core/storage/secret_pin_storage.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await VoiceTriggerService().syncStateAtAppStart();
  } catch (_) {
    // Le bridge natif sera branché progressivement.
  }

  final hasSecret = await SecretPinStorage().hasSecret();
  if (hasSecret) {
    await AppCamouflageService().ensureCalculatorCamouflageApplied();
  }
  runApp(SafeApp(hasSecret: hasSecret));
}

class SafeApp extends StatelessWidget {
  final bool hasSecret;

  const SafeApp({super.key, required this.hasSecret});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: hasSecret ? AppRouter.unlock : AppRouter.welcome,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}