import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const ink = Color(0xFF151124);
  static const surface = Color(0xFF211A35);
  static const card = Color(0xFF2C2345);
  static const cream = Color(0xFFFFF2D8);
  static const gold = Color(0xFFF4B844);
  static const turquoise = Color(0xFF2FC8B3);
  static const coral = Color(0xFFFF6B5D);
  static const muted = Color(0xFFA79DBE);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.turquoise,
    brightness: Brightness.dark,
    surface: AppColors.surface,
  ).copyWith(
    primary: AppColors.turquoise,
    secondary: AppColors.gold,
    error: AppColors.coral,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ink,
    fontFamily: 'sans-serif',
    cardTheme: const CardTheme(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF1A152A),
      indicatorColor: Color(0x402FC8B3),
      height: 72,
    ),
  );
}
