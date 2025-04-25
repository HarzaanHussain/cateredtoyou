// theme_manager.dart
// Lightweight preset-based theme manager (no dark‑mode)
// ─────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Pre‑defined UI palettes your app can switch between.
/// Extend the enum if you add more colour schemes later.
enum ThemePreset {
  honey,
  royalBlue,
}

/// Holds the active [ThemePreset] and notifies listeners when it changes.
///
/// Usage:
/// ```dart
/// final tm = context.read<ThemeManager>();
/// tm.setPreset(ThemePreset.royalBlue);
/// ```
class ThemeManager with ChangeNotifier {
  ThemePreset _preset = ThemePreset.honey;

  ThemePreset get preset => _preset;

  /// Call this to change the global theme.
  void setPreset(ThemePreset value) {
    if (_preset == value) return; // no‑op if unchanged
    _preset = value;
    notifyListeners(); // triggers rebuild of MaterialApp
  }
}


/// Robust Theme Manager Implementation should we choose to use.
/// 
/// 
/// 
/// Manages the current theme mode (light/dark) 
/// Currently disabled 
/*class ThemeManager extends ChangeNotifier {
  bool _isDarkMode = false;
  
  bool get isDarkMode => _isDarkMode;
  
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  
  void toggleTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }
} */
//
//
// Thomas OG light Theme

//
//
/*
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  primaryColor: const Color(0xFFFBC72B),
  scaffoldBackgroundColor: const Color(0xFFFCF8F2), // Off-white background / this should be white
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFFBC72B),
    brightness: Brightness.light,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFFFC533), // Gold button background
      foregroundColor: Colors.black,           // Button text color
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.all(Colors.white),
    trackColor: MaterialStateProperty.all(Colors.green),
    overlayColor: MaterialStateProperty.all(Colors.green.withOpacity(0.4)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  cardTheme: CardTheme(
    elevation: 2,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    margin: const EdgeInsets.symmetric(vertical: 8),
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),
);

/// Updated dark theme that does not use the deprecated `background` parameter.
/// It relies on scaffoldBackgroundColor for the global background color.
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF1A252F),
    onPrimary: Colors.white,
    secondary: Color(0xFFCBA135),
    onSecondary: Colors.white,
    surface: Color(0xFF121212),
    onSurface: Colors.white70,
    error: Colors.red,
    onError: Colors.black,
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1A252F),
    foregroundColor: Colors.white,
    elevation: 4,
  ),
);  */
