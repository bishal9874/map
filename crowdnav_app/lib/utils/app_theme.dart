import 'package:flutter/material.dart';

/// App-wide color scheme and design tokens
class AppTheme {
  // Primary palette - Deep ocean blue
  static const Color primary = Color(0xFF1A73E8);
  static const Color primaryLight = Color(0xFF4DA3FF);
  static const Color primaryDark = Color(0xFF0D47A1);

  // Accent - Vibrant coral
  static const Color accent = Color(0xFFFF6B6B);
  static const Color accentLight = Color(0xFFFF9B9B);

  // Surface colors
  static const Color surface = Color(0xFF1E1E2E);
  static const Color surfaceLight = Color(0xFF2D2D44);
  static const Color surfaceCard = Color(0xFF252540);
  static const Color surfaceOverlay = Color(0x99000000);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFB300);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF29B6F6);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0C0);
  static const Color textMuted = Color(0xFF6B6B80);

  // Report type colors
  static const Map<String, Color> reportColors = {
    'road_blocked': Color(0xFFEF5350),
    'traffic': Color(0xFFFFB300),
    'accident': Color(0xFFFF5722),
    'personal_preference': Color(0xFF66BB6A),
    'other': Color(0xFF78909C),
  };

  // Report type icons  
  static const Map<String, IconData> reportIcons = {
    'road_blocked': Icons.block_rounded,
    'traffic': Icons.traffic_rounded,
    'accident': Icons.car_crash_rounded,
    'personal_preference': Icons.alt_route_rounded,
    'other': Icons.warning_amber_rounded,
  };

  // Report type labels
  static const Map<String, String> reportLabels = {
    'road_blocked': 'Road Blocked',
    'traffic': 'Heavy Traffic',
    'accident': 'Accident',
    'personal_preference': 'Personal Preference',
    'other': 'Other',
  };

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: surface,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
