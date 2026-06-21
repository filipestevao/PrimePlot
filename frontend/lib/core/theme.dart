// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';

class PrimeTheme {
  // Bluish-slate dark mode palette based on Goal_app
  static const Color backgroundDark = Color(0xFF0F1523); // Darker background to make panels float
  static const Color panelBackground = Color(0xFF1C2331); // The blueish panel color
  static const Color titleBarBackground = Color(0xFF1C2331); // Match the panel color
  static const Color primaryAccent = Color(0xFF00A2FF); // Vibrant blue
  static const Color borderSide = Color(0xFF2C364C);
  static const Color textPrimary = Color(0xFFE2E8F0); // Slate 200
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color tabBackground = Color(0xFF242C3D); // Slightly lighter than panel
  static const Color searchBarBackground = Color(0xFF141923); // Darker input field

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
