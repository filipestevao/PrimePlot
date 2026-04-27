import 'package:flutter/material.dart';

class PrimeTheme {
  // Deep, modern dark mode palette
  static const Color backgroundDark = Color(0xFF1E1E1E);
  static const Color panelBackground = Color(0xFF252526);
  static const Color titleBarBackground = Color(0xFF323233);
  static const Color primaryAccent = Color(0xFF007ACC);
  static const Color borderSide = Color(0xFF454545);
  static const Color textPrimary = Color(0xFFCCCCCC);
  static const Color textSecondary = Color(0xFF858585);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryAccent,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        surface: panelBackground,
        // ignore: deprecated_member_use
        background: backgroundDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: titleBarBackground,
        elevation: 0,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: textPrimary, fontSize: 13),
        labelLarge: TextStyle(color: textSecondary, fontSize: 12),
      ),
      useMaterial3: true,
    );
  }
}
