import 'package:flutter/material.dart';

/// Manages the current theme mode (light/dark) 
/// Currently disabled 
class ThemeManager extends ChangeNotifier {
  bool _isDarkMode = false;
  
  bool get isDarkMode => _isDarkMode;
  
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  
  void toggleTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }
}
// Thomas OG light theme 

//
//
/*
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  primaryColor: const Color(0xFFFBC72B),
  scaffoldBackgroundColor: const Color(0xFFFCF8F2), // Off-white background
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
