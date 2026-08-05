import 'dart:async';

import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../models/master_arrear_setting.dart';
import '../network/api_exception.dart';
import '../network/api_service.dart';
import '../utils/persistence_service.dart';
import 'employee_controller.dart';

class ArrearsSettingsController extends GetxController {
  ArrearsSettingsController({PersistenceService? persistence, ApiService? apiService})
      : _persistence = persistence ?? PersistenceService(),
        _api = apiService ?? ApiService();

  static const _key = 'tughe_master_arrears';

  final PersistenceService _persistence;
  final ApiService _api;
  final RxList<MasterArrearSetting> masterArrears = <MasterArrearSetting>[].obs;
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

    List<MasterArrearSetting>? cached;
    final raw = await _persistence.readJson(_key);
    if (raw is List) {
      try {
        cached = raw.map((e) => MasterArrearSetting.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        cached = null;
      }
    }

    try {
      await _fetchFromBackend(mergeBase: cached ?? const []);
      errorMessage.value = '';
    } catch (error) {
      if (cached != null) masterArrears.assignAll(cached);
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
      await _fetchFromBackend(mergeBase: masterArrears);
      errorMessage.value = '';
    } catch (error) {
      if (error is ApiException && !error.isNetworkError) {
        errorMessage.value = error.message;
        Get.snackbar('Imeshindwa kupakua mipangilio ya deni', error.message);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _fetchFromBackend({required List<MasterArrearSetting> mergeBase}) async {
    final byBackendId = {for (final a in mergeBase) if (a.backendId != null) a.backendId!: a};
    final backendList = await _api.searchArrearSettings();
    final merged = backendList
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .where((json) => json['isBlocked'] != true)
        .map((json) {
      final id = (json['id'] as num?)?.toInt();
      return MasterArrearSetting.fromBackendJson(json, previous: byBackendId[id]);
    }).toList();
    masterArrears.assignAll(merged);
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final json = masterArrears.map((e) => e.toJson()).toList();
    await _persistence.writeJson(_key, json);
  }

  void saveSetting(MasterArrearSetting setting) {
    final index = masterArrears.indexWhere((m) => m.id == setting.id);
    if (index != -1) {
      masterArrears[index] = setting;
    } else {
      masterArrears.add(setting);
    }
    unawaited(_persist());

    _api
        .saveArrearSetting(
      id: setting.backendId ?? 0,
      name: setting.name,
      key: setting.arrearsType.toUpperCase(),
      deductionModel: setting.deductionType.toUpperCase(),
      percentOrAmount: setting.defaultValue,
    )
        .then((created) {
      final i = masterArrears.indexWhere((m) => m.id == setting.id);
      if (i != -1 && setting.backendId == null) {
        masterArrears[i] = setting.copyWith(backendId: (created['id'] as num?)?.toInt());
        unawaited(_persist());
      }
    }).catchError((error) {
      Get.snackbar('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kuhifadhi mpangilio wa deni (${setting.name}).');
    });
  }

  void deleteSetting(String id) {
    final setting = masterArrears.firstWhereOrNull((m) => m.id == id);
    masterArrears.removeWhere((m) => m.id == id);
    unawaited(_persist());

    final backendId = setting?.backendId;
    if (backendId == null) return;
    // The backend only supports a soft "block" (there is no hard delete
    // for master arrears settings), which is the correct behaviour anyway
    // since employees may already reference this setting historically.
    _api.blockArrearSetting(backendId).catchError((error) {
      Get.snackbar('Imeshindikana', error is ApiException ? error.message : 'Imeshindwa kufuta mpangilio.');
    });
  }

  String generateNextId() {
    final numbers = masterArrears
        .map((m) => int.tryParse(m.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final next = (numbers.isEmpty ? 0 : numbers.reduce((a, b) => a > b ? a : b)) + 1;
    return 'ARR-${next.toString().padLeft(3, '0')}';
  }

  /// Pushes [setting]'s current value to every employee already assigned
  /// it - use this after changing a rate (e.g. NSSF went from 10% to
  /// 12%) so everyone is brought up to date in one go, instead of editing
  /// each employee's assignment individually before running payroll.
  Future<void> syncSettingToEmployees(MasterArrearSetting setting) async {
    final backendId = setting.backendId;
    if (backendId == null) {
      Get.snackbar('Haiwezekani', 'Mpangilio huu bado haujahifadhiwa kwenye seva.');
      return;
    }
    try {
      final result = await _api.syncArrearSettingToEmployees(backendId);
      final count = (result['employeesUpdated'] as num?)?.toInt() ?? 0;
      Get.snackbar('Imefanikiwa',
          'Wafanyakazi $count wamesasishwa na thamani mpya ya "${setting.name}".');
      // The sync happened server-side, but EmployeeController's cached
      // employee data (arrearsList amounts) is now stale until refetched -
      // without this, the UI would keep showing the OLD value even though
      // the database is already correct.
      if (Get.isRegistered<EmployeeController>()) {
        unawaited(Get.find<EmployeeController>().refreshFromBackend());
      }
    } catch (error) {
      Get.snackbar('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kusasisha wafanyakazi.');
    }
  }
}
