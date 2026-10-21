import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/persistence_service.dart';
import 'translations.dart';

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
      appIsEnglish = true;
      notifyListeners();
    }
  }

  void setLanguage(AppLanguage lang) {
    if (_language == lang) return;
    _language = lang;
    appIsEnglish = lang == AppLanguage.en;
    notifyListeners();
    unawaited(_persistence.writeJson(_key, lang == AppLanguage.en ? 'en' : 'sw'));
  }

  void toggle() => setLanguage(_language == AppLanguage.sw ? AppLanguage.en : AppLanguage.sw);
}

/// Translates [key] to the current language, given [isEnglish]. The
/// dictionary lives in translations.dart (generated); strings with no
/// translation are returned unchanged, so a missing entry never breaks a screen.
String t(String key, {required bool isEnglish}) {
  if (!isEnglish) return key;
  return translateText(key);
}
