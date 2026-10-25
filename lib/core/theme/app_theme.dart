import 'package:flutter/material.dart';

/// Design tokens and typography for the AlQalam Web Data Collection Portal.
class AppColors {
  // Brand Palette: Deep Islamic Emerald & Warm Accents
  static const Color emeraldPrimary = Color(0xFF065F46);
  static const Color emeraldDark = Color(0xFF044E3A);
  static const Color emeraldLight = Color(0xFFECFDF5);
  static const Color emeraldBorder = Color(0xFFA7F3D0);

  // Accent & Gold
  static const Color goldAccent = Color(0xFFD97706);
  static const Color goldLight = Color(0xFFFEF3C7);

  // Intentional Error Notice Banner (Pack D) - Strict Spec Section 2.3
  static const Color noticeAmberBg = Color(0xFFFFFBEB);
  static const Color noticeAmberBorder = Color(0xFFFCD34D);
  static const Color noticeAmberText = Color(0xFF78350F);
  static const Color noticeAmberIcon = Color(0xFFB45309);

  // Neutral & Canvas Slate
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color cardBg = Colors.white;
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // Canvas Ink & Drawing Guideline
  static const Color canvasPaper = Colors.white;
  static const Color canvasInk = Color(0xFF000000);
  static const Color canvasGuideline = Color(0xFFE2E8F0);
  static const Color canvasBaseline = Color(0xFFCBD5E1);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.emeraldPrimary,
        primary: AppColors.emeraldPrimary,
        secondary: AppColors.goldAccent,
        surface: AppColors.backgroundLight,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      fontFamily: 'Amiri',
      fontFamilyFallback: const [
        'Traditional Arabic',
        'Scheherazade New',
        'Arial',
        'sans-serif',
      ],
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.slate200, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.slate900,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
