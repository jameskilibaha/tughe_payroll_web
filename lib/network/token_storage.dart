import 'package:shared_preferences/shared_preferences.dart';

/// Persists the JWT auth token across sessions.
/// Mirrors `localStorage.getItem('tughe_jwt_token')` from the React app.
class TokenStorage {
  static const _key = 'tughe_jwt_token';

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
