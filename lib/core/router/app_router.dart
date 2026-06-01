import 'package:flutter/material.dart';
import 'package:safeg/features/onboarding/screens/welcome_screen.dart';
import 'package:safeg/features/onboarding/screens/profile_screen.dart';
import 'package:safeg/features/onboarding/screens/contacts_screen.dart';
import 'package:safeg/features/onboarding/screens/trigger_screen.dart';
import 'package:safeg/features/onboarding/screens/pin_screen.dart';
import 'package:safeg/features/onboarding/screens/home_screen.dart';
import 'package:safeg/features/onboarding/screens/settings_screen.dart';

class AppRouter {
  static const welcome  = '/';
  static const profile  = '/onboarding/profile';
  static const contacts = '/onboarding/contacts';
  static const trigger  = '/onboarding/trigger';
  static const pin      = '/onboarding/pin';
  static const home     = '/home';
  static const settings = '/settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case welcome:          return _fade(const WelcomeScreen());
      case profile:          return _fade(const ProfileScreen());
      case contacts:         return _fade(const ContactsScreen());
      case trigger:          return _fade(const TriggerScreen());
      case pin:              return _fade(const PinScreen());
      case home:             return _fade(const HomeScreen());
      case AppRouter.settings: return _fade(const SettingsScreen());
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