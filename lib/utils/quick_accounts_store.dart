import 'persistence_service.dart';

/// An account the person chose to keep on the login screen for one-tap sign-in.
///
/// The password is OPTIONAL. When it is saved it lives in this browser's local
/// storage in plain text, so it is only meant for the person's own computer; without
/// it, tapping the account just fills in the username.
class QuickAccount {
  const QuickAccount({required this.label, required this.username, this.password});

  final String label; // shown on the tile, e.g. "Mhasibu Mkuu"
  final String username;
  final String? password;

  bool get hasPassword => password != null && password!.isNotEmpty;

  String get initials {
    final source = label.trim().isEmpty ? username : label;
    final parts = source.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((s) => s[0]).join().toUpperCase();
  }

  Map<String, dynamic> toJson() => {'label': label, 'username': username, if (hasPassword) 'password': password};

  factory QuickAccount.fromJson(Map<String, dynamic> json) => QuickAccount(
        label: (json['label'] as String?) ?? '',
        username: (json['username'] as String?) ?? '',
        password: json['password'] as String?,
      );
}

/// Saves the quick-login accounts on this browser.
class QuickAccountsStore {
  QuickAccountsStore({PersistenceService? persistence}) : _persistence = persistence ?? PersistenceService();

  static const _key = 'tughe_quick_accounts';
  final PersistenceService _persistence;

  Future<List<QuickAccount>> load() async {
    final raw = await _persistence.readJson(_key);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => QuickAccount.fromJson(Map<String, dynamic>.from(m)))
        .where((a) => a.username.isNotEmpty)
        .toList();
  }

  Future<void> save(List<QuickAccount> accounts) =>
      _persistence.writeJson(_key, accounts.map((a) => a.toJson()).toList());
}
