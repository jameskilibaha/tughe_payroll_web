import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/persistence_service.dart';

enum AppLanguage { sw, en }

/// Provider-managed language toggle (Kiswahili/English), persisted across
/// app restarts - same pattern as ThemeProvider in theme.dart.
class LocaleProvider extends ChangeNotifier {
  LocaleProvider({PersistenceService? persistence}) : _persistence = persistence ?? PersistenceService() {
    _restore();
  }

  static const _key = 'tughe_language';

  final PersistenceService _persistence;
  AppLanguage _language = AppLanguage.sw;

  AppLanguage get language => _language;
  bool get isEnglish => _language == AppLanguage.en;

  Future<void> _restore() async {
    final saved = await _persistence.readJson(_key);
    if (saved == 'en') {
      _language = AppLanguage.en;
      notifyListeners();
    }
  }

  void setLanguage(AppLanguage lang) {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    unawaited(_persistence.writeJson(_key, lang == AppLanguage.en ? 'en' : 'sw'));
  }

  void toggle() => setLanguage(_language == AppLanguage.sw ? AppLanguage.en : AppLanguage.sw);
}

/// Translation dictionary. Keys are the Swahili source strings already used
/// throughout the app; `t(key)` returns the current-language text, falling
/// back to the Swahili key itself for anything not yet translated (so
/// switching to English never shows a blank/broken label - untranslated
/// screens simply stay in Swahili until translated).
///
/// NOTE: this dictionary currently covers the app "chrome" that surrounds
/// every screen - the sidebar navigation, header, and login screen. The
/// dozens of individual feature screens (employee registration, arrears/
/// allowances dialogs, reports, payroll, settings, etc.) each have their
/// own hundreds of hardcoded Swahili strings that are NOT yet wired through
/// this dictionary - translating those is a large, separate, incremental
/// task (screen by screen), not something completed here.
const Map<String, String> _swToEn = {
  // Sidebar / navigation (must match the exact Swahili strings used in
  // sidebar.dart's _NavItem list)
  'MODULI KUU': 'MAIN MODULES',
  'MIPANGILIO (SETTINGS)': 'SETTINGS',
  'Muhtasari (Dashboard)': 'Overview (Dashboard)',
  'Usajili wa Wafanyakazi': 'Employee Registration',
  'Employee Registration': 'Employee Registration',
  'Hali ya Mshahara': 'Salary Status',
  'Salary Status': 'Salary Status',
  'Makato (Arrears)': 'Arrears',
  'Employee Arrears': 'Employee Arrears',
  'Nyongeza (Allowances)': 'Allowances',
  'Employee Allowances': 'Employee Allowances',
  'Endesha Payroll': 'Run Payroll',
  'Generate / Reverse Payroll': 'Generate / Reverse Payroll',
  'Hati ya Mshahara': 'Salary Slip',
  'Salary Slip / Payslip': 'Salary Slip / Payslip',
  'Sehemu ya Ripoti': 'Reports',
  'Form ya Arrears': 'Arrears Form',
  'Settings za Makato': 'Arrears Settings',
  'Form ya Allowances': 'Allowances Form',
  'TRA Formula Settings': 'TRA Formula Settings',
  'User Controller & Audit': 'User Controller & Audit',
  'Password, Block, Audit Log': 'Password, Block, Audit Log',
  'CHAMA CHA TUGHE': 'TUGHE UNION',
  'Mfumo wa Mshahara & Posho': 'Payroll & Allowances System',
  'MFUMO UPO HAI': 'SYSTEM ONLINE',

  // Header
  'MFUMO WA TUGHE PAYROLL': 'TUGHE PAYROLL SYSTEM',
  'Tafuta Mfanyakazi / ID...': 'Search Employee / ID...',
  'Toka kwenye Mfumo (Sign Out)': 'Sign Out',
  'Hai': 'Active',
  'Fungiwa': 'Blocked',
  'Jumla': 'Total',

  // Login screen
  'Karibu TUGHE Payroll': 'Welcome to TUGHE Payroll',
  'Chama cha Wafanyakazi wa Serikali na Afya Tanzania': 'Tanzania Union of Government and Health Employees',
  'PORTAL YA UHAKIKI NA INGIA (AUTHENTICATION)': 'AUTHENTICATION PORTAL',
  'Umesahau Nenosiri?': 'Forgot Password?',
  'INGIA MFUMONI (SIGN IN)': 'SIGN IN',
  'Ingia kwenye Akaunti Yako': 'Sign in to Your Account',
  'Jina la Mtumiaji': 'Username',
  'Nywila': 'Password',
  'Ingia': 'Login',
  'Ingia (Login)': 'Login',

  // Common buttons used app-wide
  'Hifadhi': 'Save',
  'Ghairi': 'Cancel',
  'Futa': 'Delete',
  'Hariri': 'Edit',
  'Ongeza': 'Add',
  'Rudi Nyuma': 'Go Back',
  'Ndiyo, Endelea': 'Yes, Continue',
};

/// Translates [key] to the current language, given [isEnglish]. Falls back
/// to the Swahili [key] itself if no translation exists yet.
String t(String key, {required bool isEnglish}) {
  if (!isEnglish) return key;
  return _swToEn[key] ?? key;
}
