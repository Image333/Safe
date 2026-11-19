import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/services/app_camouflage_service.dart';
import 'core/services/voice_trigger_service.dart';
import 'core/storage/secret_pin_storage.dart';
import 'core/theme/app_theme.dart';

bool appHasSecret = false;
bool appIsLocked = false;

// Service global pour la reconnaissance vocale
final voiceTriggerService = VoiceTriggerService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Déterminer si l'app a un secret AVANT toute autre opération
  bool hasSecret = false;
  try {
    hasSecret = await SecretPinStorage().hasSecret();
  } catch (e) {
    debugPrint('Erreur SecretPinStorage: $e');
  }
  
  appHasSecret = hasSecret;
  appIsLocked = hasSecret; // Au démarrage, l'app est toujours verrouillée si elle a un PIN
  
  // Lancer l'app immédiatement, puis synchroniser en arrière-plan
  runApp(SafeApp(hasSecret: hasSecret));
  
  // Opérations non-bloquantes en arrière-plan APRÈS le lancement de l'UI
  _initializeBackgroundServices(hasSecret);
}

/// Initialise les services en arrière-plan sans bloquer l'UI
Future<void> _initializeBackgroundServices(bool hasSecret) async {
  // Synchroniser l'état du voice trigger au démarrage (non-bloquant)
  try {
    await voiceTriggerService.syncStateAtAppStart();
  } catch (e) {
    debugPrint('Erreur VoiceTriggerService: $e');
  }

  // Appliquer le camouflage calculatrice si nécessaire
  if (hasSecret) {
    try {
      await AppCamouflageService().ensureCalculatorCamouflageApplied();
    } catch (e) {
      debugPrint('Erreur AppCamouflageService: $e');
    }
  }
}

class SafeApp extends StatefulWidget {
  final bool hasSecret;

  const SafeApp({super.key, required this.hasSecret});

  @override
  State<SafeApp> createState() => _SafeAppState();
}

class _SafeAppState extends State<SafeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    debugPrint('📱 App lifecycle: $state');
    
    switch (state) {
      case AppLifecycleState.paused:
        // App en arrière-plan - l'écoute continue via le code natif iOS
        debugPrint('📱 App en arrière-plan');
        break;
      case AppLifecycleState.resumed:
        // App revenue au premier plan - resynchroniser si nécessaire
        debugPrint('📱 App revenue au premier plan');
        _resyncVoiceTrigger();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _resyncVoiceTrigger() async {
    try {
      await voiceTriggerService.syncStateAtAppStart();
    } catch (e) {
      debugPrint('Erreur resync VoiceTrigger: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: widget.hasSecret ? AppRouter.unlock : AppRouter.welcome,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}