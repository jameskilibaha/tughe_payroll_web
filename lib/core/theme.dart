import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/persistence_service.dart';

/// Approximates the Tailwind slate/blue palette used across the original
/// React UI (bg-slate-100, text-slate-900, selection:bg-blue-600, etc.).
class AppColors {
  static const primaryBlue = Color(0xFF2563EB); // blue-600
  static const darkBlue = Color(0xFF1D4ED8); // blue-700
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate400 = Color(0xFF94A3B8);
  static const slate600 = Color(0xFF475569);
  static const slate900 = Color(0xFF0F172A);
  static const success = Color(0xFF16A34A); // green-600
  static const danger = Color(0xFFDC2626); // red-600
  static const warning = Color(0xFFD97706); // amber-600

  // Dark-mode surface colors
  static const darkSurface = Color(0xFF1E293B); // slate-800
  static const darkBackground = Color(0xFF0F172A); // slate-900
  static const darkBorder = Color(0xFF334155); // slate-700
}

/// Provider-managed theme toggle (light/dark), independent of the GetX
/// controllers used for business/domain state. Persists the choice across
/// app restarts.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider({PersistenceService? persistence}) : _persistence = persistence ?? PersistenceService() {
    _restore();
  }

  static const _key = 'tughe_theme_mode';

  final PersistenceService _persistence;
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> _restore() async {
    final saved = await _persistence.readJson(_key);
    if (saved == 'dark') {
      _mode = ThemeMode.dark;
      notifyListeners();
    }
  }

  void toggle() {
    _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    unawaited(_persistence.writeJson(_key, _mode == ThemeMode.dark ? 'dark' : 'light'));
  }
}

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.slate100,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.light,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.slate900,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.slate200),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.dark,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    dividerColor: AppColors.darkBorder,
  );
}
