import 'dart:async';

import 'package:get/get.dart';

import '../models/audit_log_entry.dart';
import '../network/api_exception.dart';
import '../network/api_service.dart';
import '../utils/persistence_service.dart';
import '../core/tr_snack.dart';

class AuditController extends GetxController {
  AuditController({PersistenceService? persistence, ApiService? apiService})
      : _persistence = persistence ?? PersistenceService(),
        _api = apiService ?? ApiService();

  static const _key = 'tughe_audit_logs';

  final PersistenceService _persistence;
  final ApiService _api;
  final RxList<AuditLogEntry> auditLogs = <AuditLogEntry>[].obs;
  final RxBool isLoading = true.obs;

  /// Non-empty only when the last fetch genuinely failed. Never masked by
  /// sample/dummy data.
  final RxString errorMessage = ''.obs;

  final Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final token = await _api.tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      isLoading.value = false;
      if (!_ready.isCompleted) _ready.complete();
      return;
    }

    List<AuditLogEntry>? cached;
    final raw = await _persistence.readJson(_key);
    if (raw is List) {
      try {
        cached = raw.map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        cached = null;
      }
    }

    try {
      await _fetchFromBackend();
      errorMessage.value = '';
    } catch (error) {
      if (cached != null) auditLogs.assignAll(cached);
      errorMessage.value =
          error is ApiException ? error.message : 'Imeshindwa kuunganisha na seva. Angalia mtandao wako.';
    } finally {
      isLoading.value = false;
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  bool _isRefreshing = false;

  Future<void> refreshFromBackend() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      await _fetchFromBackend();
      errorMessage.value = '';
    } catch (error) {
      if (error is ApiException && !error.isNetworkError) {
        errorMessage.value = error.message;
        trSnack('Imeshindwa kupakua kumbukumbu (audit log)', error.message);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// The screen shows the newest entries only (a busy system records every request, so the whole
  /// history can be very large); the CSV export asks for everything.
  static const int screenLimit = 3000;

  /// The WHOLE audit history, newest first - for the CSV export. Throws [ApiException].
  Future<List<AuditLogEntry>> fetchAllForExport() async {
    final backendList = await _api.searchAuditLogs();
    return backendList
        .map((raw) => AuditLogEntry.fromBackendJson(Map<String, dynamic>.from(raw as Map)))
        .toList()
        .reversed
        .toList();
  }

  Future<void> _fetchFromBackend() async {
    final backendList = await _api.searchAuditLogs(limit: screenLimit);
    // An empty result is a legitimate answer (a fresh system truly has no
    // history yet) - show it as-is rather than falling back to sample
    // dummy entries, which would misrepresent real audit history.
    final mapped = backendList
        .map((raw) => AuditLogEntry.fromBackendJson(Map<String, dynamic>.from(raw as Map)))
        .toList()
        .reversed // newest first, matching the local insert(0, ...) order below
        .toList();
    auditLogs.assignAll(mapped);
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final json = auditLogs.map((e) => e.toJson()).toList();
    await _persistence.writeJson(_key, json);
  }

  void addLog({
    required String userName,
    required String userRole,
    required String action,
    required String details,
    required String category,
    String? ipAddress,
  }) {
    final entry = AuditLogEntry(
      id: 'AUD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      timestamp: DateTime.now().toIso8601String().replaceFirst('T', ' ').substring(0, 19),
      userName: userName,
      userRole: userRole,
      action: action,
      details: details,
      category: category,
      ipAddress: ipAddress,
    );
    auditLogs.insert(0, entry);
    unawaited(_persist());

    // Best-effort central logging - the UI list already has the entry
    // regardless of whether this succeeds.
    _api
        .createAuditLog(tableId: 0, tableName: category, actionType: action, oldData: '', newData: details)
        .catchError((_) {
      // Silently ignored: local audit history is already recorded above,
      // and surfacing a snackbar for every background log write would be
      // noisy rather than useful.
      return <String, dynamic>{};
    });
  }

  void clearLogs() {
    auditLogs.clear();
    unawaited(_persist());
  }
}
