import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              // Logo / icône
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.shield_outlined, size: 40, color: AppColors.white),
              ),
              const SizedBox(height: 32),
              const Text(
                'safe',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'Votre protection discrète,\ntoujours avec vous.',
                style: TextStyle(
                  fontSize: 18, color: AppColors.white.withOpacity(0.8), height: 1.5,
                ),
              ),
              const Spacer(flex: 3),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.navy,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: () => Navigator.pushNamed(context, AppRouter.profile),
                child: const Text('Commencer'),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Vos données ne quittent jamais votre téléphone',
                  style: TextStyle(fontSize: 13, color: AppColors.white.withOpacity(0.5)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}