import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around SharedPreferences string storage, mirroring the
/// `localStorage.setItem/getItem` persistence used throughout the original
/// React app (see App.tsx `useEffect` sync blocks). Each controller handles
/// its own (de)serialization via each model's `toJson()` / `fromJson()`,
/// keeping this class free of generic-type gymnastics.
class PersistenceService {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> writeJson(String key, Object jsonValue) async {
    final prefs = await _prefs;
    await prefs.setString(key, jsonEncode(jsonValue));
  }

  Future<dynamic> readJson(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }
}
