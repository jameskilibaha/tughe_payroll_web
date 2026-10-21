import 'dart:async';

import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../models/master_allowance_setting.dart';
import '../network/api_exception.dart';
import '../network/api_service.dart';
import '../utils/persistence_service.dart';
import 'employee_controller.dart';
import '../core/tr_snack.dart';

class AllowancesSettingsController extends GetxController {
  AllowancesSettingsController({PersistenceService? persistence, ApiService? apiService})
      : _persistence = persistence ?? PersistenceService(),
        _api = apiService ?? ApiService();

  static const _key = 'tughe_master_allowances';

  final PersistenceService _persistence;
  final ApiService _api;
  final RxList<MasterAllowanceSetting> masterAllowances = <MasterAllowanceSetting>[].obs;
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

    List<MasterAllowanceSetting>? cached;
    final raw = await _persistence.readJson(_key);
    if (raw is List) {
      try {
        cached = raw.map((e) => MasterAllowanceSetting.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        cached = null;
      }
    }

    try {
      await _fetchFromBackend(mergeBase: cached ?? const []);
      errorMessage.value = '';
    } catch (error) {
      if (cached != null) masterAllowances.assignAll(cached);
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
      await _fetchFromBackend(mergeBase: masterAllowances);
      errorMessage.value = '';
    } catch (error) {
      if (error is ApiException && !error.isNetworkError) {
        errorMessage.value = error.message;
        trSnack('Imeshindwa kupakua mipangilio ya posho', error.message);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _fetchFromBackend({required List<MasterAllowanceSetting> mergeBase}) async {
    final byBackendId = {for (final a in mergeBase) if (a.backendId != null) a.backendId!: a};
    final backendList = await _api.searchAllowanceSettings();
    final merged = backendList
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .where((json) => json['isBlocked'] != true)
        .map((json) {
      final id = (json['id'] as num?)?.toInt();
      return MasterAllowanceSetting.fromBackendJson(json, previous: byBackendId[id]);
    }).toList();
    masterAllowances.assignAll(merged);
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final json = masterAllowances.map((e) => e.toJson()).toList();
    await _persistence.writeJson(_key, json);
  }

  void saveSetting(MasterAllowanceSetting setting) {
    final index = masterAllowances.indexWhere((m) => m.id == setting.id);
    if (index != -1) {
      masterAllowances[index] = setting;
    } else {
      masterAllowances.add(setting);
    }
    unawaited(_persist());

    _api
        .saveAllowanceSetting(
      id: setting.backendId ?? 0,
      name: setting.name,
      additionModel: setting.additionType.toUpperCase(),
      allowancesType: setting.allowanceType.toUpperCase(),
      percentOrAmount: setting.defaultValue,
      isForEverOne: setting.isForEveryone,
      isTaxable: setting.isTaxable,
    )
        .then((created) {
      final i = masterAllowances.indexWhere((m) => m.id == setting.id);
      if (i != -1 && setting.backendId == null) {
        masterAllowances[i] = setting.copyWith(backendId: (created['id'] as num?)?.toInt());
        unawaited(_persist());
      }
    }).catchError((error) {
      trSnack('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kuhifadhi mpangilio wa posho (${setting.name}).');
    });
  }

  void deleteSetting(String id) {
    final setting = masterAllowances.firstWhereOrNull((m) => m.id == id);
    masterAllowances.removeWhere((m) => m.id == id);
    unawaited(_persist());

    final backendId = setting?.backendId;
    if (backendId == null) return;
    _api.blockAllowanceSetting(backendId).catchError((error) {
      trSnack('Imeshindikana', error is ApiException ? error.message : 'Imeshindwa kufuta mpangilio.');
    });
  }

  String generateNextId() {
    final numbers = masterAllowances
        .map((m) => int.tryParse(m.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final next = (numbers.isEmpty ? 0 : numbers.reduce((a, b) => a > b ? a : b)) + 1;
    return 'ALL-${next.toString().padLeft(3, '0')}';
  }

  /// Same as ArrearsSettingsController.syncSettingToEmployees, for allowances.
  Future<void> syncSettingToEmployees(MasterAllowanceSetting setting) async {
    final backendId = setting.backendId;
    if (backendId == null) {
      trSnack('Haiwezekani', 'Mpangilio huu bado haujahifadhiwa kwenye seva.');
      return;
    }
    try {
      final result = await _api.syncAllowanceSettingToEmployees(backendId);
      final count = (result['employeesUpdated'] as num?)?.toInt() ?? 0;
      trSnack('Imefanikiwa',
          'Wafanyakazi $count wamesasishwa na thamani mpya ya "${setting.name}".');
      if (Get.isRegistered<EmployeeController>()) {
        unawaited(Get.find<EmployeeController>().refreshFromBackend());
      }
    } catch (error) {
      trSnack('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kusasisha wafanyakazi.');
    }
  }
}
