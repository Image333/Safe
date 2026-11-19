import 'package:flutter/material.dart';
import 'package:safeg/features/onboarding/screens/welcome_screen.dart';
import 'package:safeg/features/onboarding/screens/profile_screen.dart';
import 'package:safeg/features/onboarding/screens/contacts_screen.dart';
import 'package:safeg/features/onboarding/screens/trigger_screen.dart';
import 'package:safeg/features/onboarding/screens/pin_screen.dart';
import 'package:safeg/features/onboarding/screens/home_screen.dart';
import 'package:safeg/features/onboarding/screens/settings_screen.dart';
import 'package:safeg/features/audio/screens/audio_history_screen.dart';
import '../storage/secret_pin_storage.dart';

class AppRouter {
  static const welcome  = '/';
  static const profile  = '/onboarding/profile';
  static const contacts = '/onboarding/contacts';
  static const trigger  = '/onboarding/trigger';
  static const pin      = '/onboarding/pin';
  static const unlock   = '/unlock';
  static const home     = '/home';
  static const settings = '/settings';
  static const audioHistory = '/audio-history';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case welcome:          return _fade(const WelcomeScreen());
      case profile:          return _fade(const ProfileScreen());
      case contacts:
        final contactsMode = settings.arguments is ContactsScreenMode
            ? settings.arguments as ContactsScreenMode
            : ContactsScreenMode.onboarding;
        return _fade(ContactsScreen(mode: contactsMode));
      case trigger:          return _fade(const TriggerScreen());
      case pin:              return _fade(const PinScreen(mode: PinScreenMode.config));
      case unlock:           return _fade(const PinScreen(mode: PinScreenMode.unlock));
      case home:             return _fade(const _AppLockerWrapper(child: HomeScreen()));
      case AppRouter.settings: return _fade(const _AppLockerWrapper(child: SettingsScreen()));
      case AppRouter.audioHistory: return _fade(const _AppLockerWrapper(child: AudioHistoryScreen()));
      default:               return _fade(const WelcomeScreen());
    }
  }

  static PageRouteBuilder _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 300),
  );
}

/// Widget wrapper qui verrouille automatiquement l'app si elle est en arrière-plan
/// et force le retour à l'écran de déverrouillage.
class _AppLockerWrapper extends StatefulWidget {
  final Widget child;

  const _AppLockerWrapper({required this.child});

  @override
  State<_AppLockerWrapper> createState() => _AppLockerWrapperState();
}

class _AppLockerWrapperState extends State<_AppLockerWrapper>
    with WidgetsBindingObserver {
  late AppLifecycleState _lastAppState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastAppState = AppLifecycleState.paused;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && _lastAppState == AppLifecycleState.paused) {
      // L'app revient de l'arrière-plan, on la verrouille si elle a un PIN
      _lastAppState = state;
      _lockApp();
    } else {
      _lastAppState = state;
    }
  }

  void _lockApp() async {
    final hasSecret = await SecretPinStorage().hasSecret();
    if (hasSecret && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.unlock,
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}