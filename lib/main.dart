import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/storage/secret_pin_storage.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final hasSecret = await SecretPinStorage().hasSecret();
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