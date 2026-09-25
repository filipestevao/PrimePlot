// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

import 'package:flutter/material.dart';

/// Design tokens defining the color palette for a theme in PrimePlot.
class ThemeTokens {
  final String id;
  final String name;
  final Brightness brightness;
  final Color backgroundDark;
  final Color panelBackground;
  final Color titleBarBackground;
  final Color primaryAccent;
  final Color borderSide;
  final Color textPrimary;
  final Color textSecondary;
  final Color tabBackground;
  final Color searchBarBackground;
  final Color canvasBackground;
  final Color canvasGrid;
  final Color canvasAxis;
  final Color dividerColor;

  const ThemeTokens({
    required this.id,
    required this.name,
    required this.brightness,
    required this.backgroundDark,
    required this.panelBackground,
    required this.titleBarBackground,
    required this.primaryAccent,
    required this.borderSide,
    required this.textPrimary,
    required this.textSecondary,
    required this.tabBackground,
    required this.searchBarBackground,
    required this.canvasBackground,
    required this.canvasGrid,
    required this.canvasAxis,
    required this.dividerColor,
  });
}

/// Bluish-slate dark palette (PrimePlot original signature look)
const primeplotTokens = ThemeTokens(
  id: 'primeplot',
  name: 'PrimePlot',
  brightness: Brightness.dark,
  backgroundDark: Color(0xFF0F1523),
  panelBackground: Color(0xFF1C2331),
  titleBarBackground: Color(0xFF1C2331),
  primaryAccent: Color(0xFF00A2FF),
  borderSide: Color(0xFF2C364C),
  textPrimary: Color(0xFFE2E8F0),
  textSecondary: Color(0xFF94A3B8),
  tabBackground: Color(0xFF242C3D),
  searchBarBackground: Color(0xFF141923),
  canvasBackground: Color(0xFF0F1523),
  canvasGrid: Color(0xFF2C364C),
  canvasAxis: Color(0xFF94A3B8),
  dividerColor: Color(0xFF2C364C),
);

/// Neutral dark palette (charcoal / pure dark mode)
const darkTokens = ThemeTokens(
  id: 'dark',
  name: 'Dark',
  brightness: Brightness.dark,
  backgroundDark: Color(0xFF121212),
  panelBackground: Color(0xFF1E1E1E),
  titleBarBackground: Color(0xFF181818),
  primaryAccent: Color(0xFF3B82F6),
  borderSide: Color(0xFF2E2E2E),
  textPrimary: Color(0xFFECECEC),
  textSecondary: Color(0xFF9E9E9E),
  tabBackground: Color(0xFF262626),
  searchBarBackground: Color(0xFF161616),
  canvasBackground: Color(0xFF141414),
  canvasGrid: Color(0xFF2E2E2E),
  canvasAxis: Color(0xFF9E9E9E),
  dividerColor: Color(0xFF2E2E2E),
);

/// Scientific paper light palette (crisp white background, high contrast for publications)
const lightTokens = ThemeTokens(
  id: 'light',
  name: 'Light',
  brightness: Brightness.light,
  backgroundDark: Color(0xFFF1F5F9), // Slate 100
  panelBackground: Color(0xFFFFFFFF), // Pure white
  titleBarBackground: Color(0xFFE2E8F0), // Slate 200
  primaryAccent: Color(0xFF0284C7), // Sky 600
  borderSide: Color(0xFFCBD5E1), // Slate 300
  textPrimary: Color(0xFF0F172A), // Slate 900
  textSecondary: Color(0xFF64748B), // Slate 500
  tabBackground: Color(0xFFF8FAFC), // Slate 50
  searchBarBackground: Color(0xFFF1F5F9), // Slate 100
  canvasBackground: Color(0xFFFFFFFF), // Pure white
  canvasGrid: Color(0xFFE2E8F0), // Slate 200
  canvasAxis: Color(0xFF334155), // Slate 700
  dividerColor: Color(0xFFCBD5E1),
);

class PrimeTheme {
  static ThemeTokens _currentTokens = primeplotTokens;

  static ThemeTokens get tokens => _currentTokens;
  static String get currentThemeId => _currentTokens.id;

  static ThemeTokens getTokens(String themeId) {
    switch (themeId.toLowerCase()) {
      case 'light':
        return lightTokens;
      case 'dark':
        return darkTokens;
      case 'primeplot':
      default:
        return primeplotTokens;
    }
  }

  static void setTheme(String themeId) {
    _currentTokens = getTokens(themeId);
  }

  // Delegated getters to maintain 100% backward compatibility with existing widgets
  static Color get backgroundDark => _currentTokens.backgroundDark;
  static Color get panelBackground => _currentTokens.panelBackground;
  static Color get titleBarBackground => _currentTokens.titleBarBackground;
  static Color get primaryAccent => _currentTokens.primaryAccent;
  static Color get borderSide => _currentTokens.borderSide;
  static Color get textPrimary => _currentTokens.textPrimary;
  static Color get textSecondary => _currentTokens.textSecondary;
  static Color get tabBackground => _currentTokens.tabBackground;
  static Color get searchBarBackground => _currentTokens.searchBarBackground;
  static Color get canvasBackground => _currentTokens.canvasBackground;
  static Color get canvasGrid => _currentTokens.canvasGrid;
  static Color get canvasAxis => _currentTokens.canvasAxis;
  static Color get dividerColor => _currentTokens.dividerColor;

  static ThemeData get currentThemeData => themeDataFor(_currentTokens.id);

  static ThemeData themeDataFor(String themeId) {
    final t = getTokens(themeId);
    final isDark = t.brightness == Brightness.dark;

    return ThemeData(
      brightness: t.brightness,
      primaryColor: t.primaryAccent,
      scaffoldBackgroundColor: t.backgroundDark,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: t.primaryAccent,
              surface: t.panelBackground,
            )
          : ColorScheme.light(
              primary: t.primaryAccent,
              surface: t.panelBackground,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.titleBarBackground,
        elevation: 0,
      ),
      dividerColor: t.dividerColor,
      fontFamily: 'Inter',
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: t.textPrimary, fontSize: 13),
        labelLarge: TextStyle(color: t.textSecondary, fontSize: 12),
      ),
      useMaterial3: true,
    );
  }

  // Deprecated compatibility getter
  static ThemeData get darkTheme => currentThemeData;
}
