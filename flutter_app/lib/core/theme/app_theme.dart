import 'package:flutter/material.dart';

/// Central theme so every feature module renders consistently.
class AppTheme {
  AppTheme._();

  static const Color primaryGreen = Color(0xFF1A7A4C); // from prototype accent
  static const Color ink = Color(0xFF1F2933);
  static const Color muted = Color(0xFFD5D9DC);
  static const Color surface = Color(0xFFF5F6F7);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: surface,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: muted),
        ),
      ),
    );
  }
}
