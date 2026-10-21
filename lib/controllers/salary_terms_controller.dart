import 'dart:async';

import 'package:get/get.dart';

import '../models/tra_salary_term.dart';
import '../network/api_exception.dart';
import '../network/api_service.dart';
import '../utils/payroll_calculator.dart' show defaultTraTerms;
import '../utils/persistence_service.dart';
import '../core/tr_snack.dart';

class SalaryTermsController extends GetxController {
  SalaryTermsController({PersistenceService? persistence, ApiService? apiService})
      : _persistence = persistence ?? PersistenceService(),
        _api = apiService ?? ApiService();

  static const _key = 'tughe_tra_terms';

  final PersistenceService _persistence;
  final ApiService _api;
  final RxList<TRASalaryTerm> traTerms = <TRASalaryTerm>[].obs;
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

    List<TRASalaryTerm>? cached;
    final raw = await _persistence.readJson(_key);
    if (raw is List) {
      try {
        cached = raw.map((e) => TRASalaryTerm.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        cached = null;
      }
    }

    try {
      await _fetchFromBackend(mergeBase: cached);
      errorMessage.value = '';
    } catch (error) {
      if (cached != null) traTerms.assignAll(cached);
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
      await _fetchFromBackend(mergeBase: traTerms.isEmpty ? null : traTerms);
      errorMessage.value = '';
    } catch (error) {
      if (error is ApiException && !error.isNetworkError) {
        errorMessage.value = error.message;
        trSnack('Imeshindwa kupakua Vigezo vya Kodi (TRA)', error.message);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// If [mergeBase] is null/empty and the backend has nothing configured
  /// yet, `traTerms` is left empty - the screen shows an explicit "hakuna
  /// vigezo vilivyowekwa" state with the existing "Rudisha Chaguo-msingi"
  /// button, rather than silently pretending TRA defaults were already
  /// saved on the server.
  Future<void> _fetchFromBackend({required List<TRASalaryTerm>? mergeBase}) async {
    final backendList = await _api.searchSalaryTerms();
    if (backendList.isEmpty) {
      traTerms.clear();
      unawaited(_persist());
      return;
    }
    final rows = backendList.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    final row = rows.firstWhere((r) => r['isBlocked'] != true, orElse: () => rows.first);
    traTerms.assignAll(traTermsFromBackendRow(row));
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final json = traTerms.map((e) => e.toJson()).toList();
    await _persistence.writeJson(_key, json);
  }

  void saveTerms(List<TRASalaryTerm> updated) {
    final previous = traTerms.toList();
    traTerms.assignAll(updated);
    unawaited(_persist());

    final backendId = updated.isNotEmpty ? updated.first.backendId : null;
    _api
        .saveSalaryTerms(id: backendId ?? 0, flatTerms: traTermsToBackendFlat(updated))
        .then((saved) {
      final id = (saved['id'] as num?)?.toInt();
      if (id != null) {
        traTerms.assignAll(traTerms.map((t) => t.copyWith(backendId: id)).toList());
        unawaited(_persist());
      }
    }).catchError((error) {
      traTerms.assignAll(previous);
      unawaited(_persist());
      trSnack('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kuhifadhi Vigezo vya Kodi (TRA).');
    });
  }

  /// Explicit, user-initiated action ("Rudisha Chaguo-msingi" button) - not
  /// a silent fallback, so using the built-in TRA brackets here is fine.
  void resetToDefault() {
    saveTerms(defaultTraTerms);
  }
}
