import 'package:flutter/material.dart';

class AppColors {
  static const navy     = Color(0xFF1E3A5F);
  static const blue     = Color(0xFF2563EB);
  static const blueLight= Color(0xFFDBEAFE);
  static const gray     = Color(0xFF374151);
  static const grayLight= Color(0xFFF3F4F6);
  static const grayMid  = Color(0xFF9CA3AF);
  static const red      = Color(0xFFDC2626);
  static const redLight = Color(0xFFFEE2E2);
  static const green    = Color(0xFF16A34A);
  static const greenLight=Color(0xFFD1FAE5);
  static const white    = Color(0xFFFFFFFF);
  static const purpleL = Color(0xFFF3E8FF);
  static const orange  = Color(0xFFD97706);
  static const orangeL = Color(0xFFFEF3C7);
  }

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.blue,
    ),
    scaffoldBackgroundColor: AppColors.white,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.navy),
      displayMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy),
      bodyLarge:    TextStyle(fontSize: 16, color: AppColors.gray),
      bodyMedium:   TextStyle(fontSize: 14, color: AppColors.grayMid),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}