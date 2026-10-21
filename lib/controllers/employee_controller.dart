import 'dart:async';

import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../models/employee.dart';
import '../models/salary_status.dart';
import '../models/assigned_arrear.dart';
import '../models/assigned_allowance.dart';
import '../models/master_arrear_setting.dart';
import '../network/api_exception.dart';
import '../network/api_service.dart';
import '../utils/persistence_service.dart';
import 'allowances_settings_controller.dart';
import 'arrears_settings_controller.dart';
import '../core/tr_snack.dart';

class EmployeeController extends GetxController {
  EmployeeController({PersistenceService? persistence, ApiService? apiService})
      : _persistence = persistence ?? PersistenceService(),
        _api = apiService ?? ApiService();

  static const _key = 'tughe_employees';

  final PersistenceService _persistence;
  final ApiService _api;

  final RxList<Employee> employees = <Employee>[].obs;
  final RxBool isLoading = true.obs;

  /// Non-empty only when the last fetch from the backend genuinely failed
  /// (permission denied, server error, or truly offline). Screens should
  /// show this - with a retry action - instead of ever substituting fake
  /// sample data for it.
  final RxString errorMessage = ''.obs;

  final Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  int get activeCount => employees.where((e) => e.status == 'Active').length;
  int get blockedCount => employees.where((e) => e.status == 'Blocked').length;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    // No point calling the backend before the person has logged in -
    // AuthController.login() triggers a real refresh once there's a token.
    final token = await _api.tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      isLoading.value = false;
      if (!_ready.isCompleted) _ready.complete();
      return;
    }

    // Read the cache quietly (without showing it) purely so cosmetic-only
    // fields the backend doesn't store (debt-tracking flags) survive a
    // cold restart even though we now fetch from the backend first.
    List<Employee>? cached;
    final raw = await _persistence.readJson(_key);
    if (raw is List) {
      try {
        cached = raw.map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        cached = null;
      }
    }

    try {
      // Real data first: talk to the backend before showing anything else.
      await _fetchFromBackend(mergeBase: cached ?? const []);
      errorMessage.value = '';
    } catch (error) {
      // Genuinely failed - show the previously-cached real data (from a
      // past successful sync) if there is any, but NEVER sample/dummy data.
      if (cached != null) employees.assignAll(cached);
      errorMessage.value =
          error is ApiException ? error.message : 'Imeshindwa kuunganisha na seva. Angalia mtandao wako.';
    } finally {
      isLoading.value = false;
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> _persist() async {
    final json = employees.map((e) => e.toJson()).toList();
    await _persistence.writeJson(_key, json);
  }

  /// Re-fetches everything from the backend and rebuilds the full employee
  /// list, joining the separate `employees` / `employees_status` /
  /// `emp_arrears` / `emp_allowances` tables the backend keeps, into the
  /// single nested [Employee] shape the rest of the app expects.
  ///
  /// Locally-cached-only fields that the backend doesn't store yet
  /// (isDebtReduction/totalDebtAmount/remainingDebtAmount on an assigned
  /// arrear) are carried over from the previous in-memory copy by matching
  /// backend row id.
  bool _isRefreshing = false;

  Future<void> refreshFromBackend() async {
    if (_isRefreshing) return; // a fetch is already in flight - don't pile on
    _isRefreshing = true;
    try {
      await _fetchFromBackend(mergeBase: employees);
      errorMessage.value = '';
    } catch (error) {
      if (error is ApiException && !error.isNetworkError) {
        errorMessage.value = error.message;
        trSnack('Imeshindwa kupakua wafanyakazi', error.message);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _fetchFromBackend({required List<Employee> mergeBase}) async {
    final previousByBackendId = {
      for (final e in mergeBase) if (e.backendId != null) e.backendId!: e,
    };

    // One request for everything (employee + status + arrears + allowances,
    // already joined server-side) instead of the old 1 + 3*N fan-out that
    // was flooding the backend with a request per employee on every load.
    final employeesRaw = await _api.searchEmployeesFullProfile();

    // Local-only fields the backend doesn't store (isCreditOrDebit/
    // frequency on a master arrears setting) - read from the settings
    // controller if it's already up, without a hard dependency on load
    // order (see the timing note in saveArrears/saveAllowances above).
    final arrearsSettingsById = Get.isRegistered<ArrearsSettingsController>()
        ? {for (final s in Get.find<ArrearsSettingsController>().masterArrears) if (s.backendId != null) s.backendId!: s}
        : <int, MasterArrearSetting>{};

    final rebuilt = employeesRaw.map((raw) {
      final json = Map<String, dynamic>.from(raw as Map);
      final employeeId = (json['id'] as num).toInt();
      final previous = previousByBackendId[employeeId];

      final previousArrearsByBackendId = {
        for (final a in previous?.arrearsList ?? const <AssignedArrear>[])
          if (a.backendId != null) a.backendId!: a,
      };

      final statusJson = json['status'] as Map?;
      final salaryStatus = statusJson == null
          ? null
          : SalaryStatus(
              occupation: statusJson['occupation'] as String? ?? '',
              workStation: statusJson['workstation'] as String? ?? '',
              basicSalary: (statusJson['monthlyWages'] as num?)?.toDouble() ?? 0,
              bankName: statusJson['bankName'] as String? ?? '',
              bankAccountNumber: statusJson['bankAccountNumber'] as String? ?? '',
            );

      final arrearsList = ((json['arrears'] as List?) ?? const [])
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map((j) {
        final arrearsId = (j['arrears_id'] as num?)?.toInt();
        final localSetting = arrearsId != null ? arrearsSettingsById[arrearsId] : null;
        final deductionModel = (j['deductionModel'] as String? ?? 'AMOUNT').toUpperCase();
        return AssignedArrear.fromBackendJson(
          j,
          masterSettingId: 'ARR-$arrearsId',
          name: j['name'] as String? ?? '',
          deductionType: deductionModel == 'PERCENT' ? 'Percent' : (deductionModel == 'NOTHING' ? 'Nothing' : 'Amount'),
          isCreditOrDebit: localSetting?.creditDebitLabel ?? 'Credit',
          frequency: localSetting?.frequencyLabel ?? 'Mara Moja (Ones)',
          previous: previousArrearsByBackendId[(j['id'] as num?)?.toInt()],
        );
      }).toList();

      final allowancesList = ((json['allowances'] as List?) ?? const [])
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .map((j) {
        final allowanceId = (j['allowance_id'] as num?)?.toInt();
        final additionModel = (j['additionModel'] as String? ?? 'AMOUNT').toUpperCase();
        final allowancesType = (j['allowancesType'] as String? ?? 'OTHER').toUpperCase();
        return AssignedAllowance.fromBackendJson(
          j,
          masterSettingId: 'ALL-$allowanceId',
          name: j['name'] as String? ?? '',
          additionType: additionModel == 'PERCENT' ? 'Percent' : 'Amount',
          isSpecial: allowancesType == 'SPECIAL',
        );
      }).toList();

      return Employee.fromBackendJson(json, status: salaryStatus, arrears: arrearsList, allowances: allowancesList);
    }).toList();

    employees.assignAll(rebuilt);
    unawaited(_persist());
  }

  List<Employee> search(String query) {
    if (query.trim().isEmpty) return employees;
    final q = query.toLowerCase();
    return employees.where((e) {
      return e.fullName.toLowerCase().contains(q) ||
          e.id.toLowerCase().contains(q) ||
          e.email.toLowerCase().contains(q) ||
          (e.salaryStatus?.occupation.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  String _isoDate(String yyyyMmDd) => yyyyMmDd.isEmpty ? DateTime.now().toIso8601String() : '${yyyyMmDd}T00:00:00';

  Future<void> addEmployee(Employee employee) async {
    employees.insert(0, employee);
    unawaited(_persist());

    try {
      final created = await _api.saveEmployee(
        id: 0,
        employeeIdNumber: employee.employeeIdNumber,
        firstName: employee.firstName,
        middleName: employee.middleName,
        lastName: employee.lastName,
        sex: employee.gender.toUpperCase(),
        maritalStatus: employee.maritalStatus.toUpperCase(),
        nationality: employee.nationality,
        residentDistrict: employee.residentialDistrict,
        mobileNo: employee.mobileNumber,
        email: employee.email,
        dateOfBirthIso: _isoDate(employee.dateOfBirth),
        dateOfEmploymentIso: _isoDate(employee.dateOfEmployment),
      );
      final index = employees.indexWhere((e) => e.id == employee.id);
      if (index != -1) {
        employees[index] = employee.copyWith(backendId: (created['id'] as num?)?.toInt());
        unawaited(_persist());
      }
    } catch (error) {
      employees.removeWhere((e) => e.id == employee.id);
      trSnack('Imeshindikana Kusajili',
          error is ApiException ? error.message : 'Imeshindwa kusajili mfanyakazi. Angalia muunganiko wa mtandao.');
    }
  }

  Future<void> updateEmployee(Employee updated) async {
    final index = employees.indexWhere((e) => e.id == updated.id);
    if (index == -1) return;
    final previous = employees[index];
    employees[index] = updated;
    unawaited(_persist());

    try {
      await _api.saveEmployee(
        id: updated.backendId ?? 0,
        employeeIdNumber: updated.employeeIdNumber,
        firstName: updated.firstName,
        middleName: updated.middleName,
        lastName: updated.lastName,
        sex: updated.gender.toUpperCase(),
        maritalStatus: updated.maritalStatus.toUpperCase(),
        nationality: updated.nationality,
        residentDistrict: updated.residentialDistrict,
        mobileNo: updated.mobileNumber,
        email: updated.email,
        dateOfBirthIso: _isoDate(updated.dateOfBirth),
        dateOfEmploymentIso: _isoDate(updated.dateOfEmployment),
      );
    } catch (error) {
      final revertIndex = employees.indexWhere((e) => e.id == updated.id);
      if (revertIndex != -1) employees[revertIndex] = previous;
      trSnack('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kuhifadhi mabadiliko ya mfanyakazi.');
    }
  }

  /// Resolves an employee's real backend id, looking it up by
  /// [employeeIdNumber] as a last resort if [known] is null (e.g. the
  /// employee was created locally very recently and the reconciliation
  /// from the create response hasn't landed yet, or a stale cached copy
  /// without a backendId is still on screen). Returns null only if the
  /// employee genuinely can't be found on the backend at all.
  Future<int?> _resolveBackendEmployeeId(int? known, String employeeIdNumber) async {
    if (known != null) return known;
    try {
      final matches = await _api.searchEmployees(employeeIdNumber: employeeIdNumber);
      if (matches.isNotEmpty) {
        return (Map<String, dynamic>.from(matches.first as Map)['id'] as num?)?.toInt();
      }
    } catch (_) {
      // fall through to null - caller reports the failure
    }
    return null;
  }

  /// If we just resolved a backendId that was previously unknown, write it
  /// back onto the in-memory employee record so future actions don't have
  /// to look it up again.
  ///
  /// [localId] here is the local list-lookup key only (the cosmetic
  /// display id, e.g. "TGH-001") - it is NEVER sent to the backend. Only
  /// [resolved] (and [previouslyKnown]) are real numeric backend ids.
  void _reconcileBackendId(String localId, int? previouslyKnown, int resolved) {
    if (previouslyKnown != null) return;
    final idx = employees.indexWhere((e) => e.id == localId);
    if (idx != -1 && employees[idx].backendId == null) {
      employees[idx] = employees[idx].copyWith(backendId: resolved);
      unawaited(_persist());
    }
  }

  /// Uploads/replaces an employee's profile picture. [photoBase64] is a
  /// full data URL (e.g. "data:image/jpeg;base64,...").
  Future<void> updatePhoto(String localId, String photoBase64) async {
    final index = employees.indexWhere((e) => e.id == localId);
    if (index == -1) return;
    final previous = employees[index];

    final knownBackendId = previous.backendId;
    final backendId = await _resolveBackendEmployeeId(knownBackendId, previous.employeeIdNumber);
    if (backendId == null) {
      trSnack('Imeshindikana',
          'Huyu mfanyakazi hajapatikana kwenye seva bado. Subiri sekunde chache kisha jaribu tena.');
      return;
    }
    _reconcileBackendId(localId, knownBackendId, backendId);
    try {
      final result = await _api.updateEmployeePhoto(employeeId: backendId, photoBase64: photoBase64);
      final fileName = result['photoFileName'] as String?;
      final refreshIndex = employees.indexWhere((e) => e.id == localId);
      if (refreshIndex != -1) employees[refreshIndex] = employees[refreshIndex].copyWith(photoFileName: fileName);
      unawaited(_persist());
    } catch (error) {
      trSnack('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kuhifadhi picha kwenye seva.');
    }
  }

  Future<void> toggleBlockStatus(String localId) async {
    final index = employees.indexWhere((e) => e.id == localId);
    if (index == -1) return;
    final e = employees[index];
    final nextStatus = e.status == 'Active' ? 'Blocked' : 'Active';
    employees[index] = e.copyWith(status: nextStatus);
    unawaited(_persist());

    final knownBackendId = e.backendId;
    final backendId = await _resolveBackendEmployeeId(knownBackendId, e.employeeIdNumber);
    if (backendId == null) {
      final revertIndex = employees.indexWhere((x) => x.id == localId);
      if (revertIndex != -1) employees[revertIndex] = e;
      trSnack('Imeshindikana',
          'Huyu mfanyakazi hajapatikana kwenye seva bado. Subiri sekunde chache kisha jaribu tena.');
      return;
    }
    _reconcileBackendId(localId, knownBackendId, backendId);
    try {
      // `backendId` (numeric) is the only employee reference the backend
      // ever sees - `localId` (e.g. "TGH-001") stays purely client-side.
      await _api.blockEmployee(backendId);
    } catch (error) {
      final revertIndex = employees.indexWhere((x) => x.id == localId);
      if (revertIndex != -1) employees[revertIndex] = e;
      trSnack('Imeshindikana', error is ApiException ? error.message : 'Imeshindwa kubadilisha hali.');
    }
  }

  Future<void> saveSalaryStatus(String localId, SalaryStatus status) async {
    final index = employees.indexWhere((e) => e.id == localId);
    if (index == -1) return;
    final previous = employees[index];
    employees[index] = previous.copyWith(salaryStatus: status);
    unawaited(_persist());

    final knownBackendId = previous.backendId;
    final backendId = await _resolveBackendEmployeeId(knownBackendId, previous.employeeIdNumber);
    if (backendId == null) {
      final revertIndex = employees.indexWhere((e) => e.id == localId);
      if (revertIndex != -1) employees[revertIndex] = previous;
      trSnack('Imeshindikana',
          'Huyu mfanyakazi hajapatikana kwenye seva bado. Subiri sekunde chache kisha jaribu tena.');
      return;
    }
    _reconcileBackendId(localId, knownBackendId, backendId);
    try {
      // `employeeId` here is ApiService's own (numeric, int) parameter -
      // `backendId` is what gets sent, never `localId`.
      await _api.saveEmployeeStatus(
        employeeId: backendId,
        occupation: status.occupation,
        workstation: status.workStation,
        monthlyWages: status.basicSalary,
        bankName: status.bankName,
        bankAccountNumber: status.bankAccountNumber,
      );
    } catch (error) {
      final revertIndex = employees.indexWhere((e) => e.id == localId);
      if (revertIndex != -1) employees[revertIndex] = previous;
      trSnack('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kuhifadhi taarifa za mshahara.');
    }
  }

  /// Deletes a single assigned arrear immediately (backend + local state),
  /// instead of waiting for "Hifadhi" - used by the dialog's "Futa Kabisa
  /// Sasa" button. Does nothing to the backend if [arrear] was never
  /// actually saved there (no backendId yet).
  Future<void> deleteArrearNow(String localId, AssignedArrear arrear) async {
    final index = employees.indexWhere((e) => e.id == localId);
    if (index == -1) return;
    final previous = employees[index];
    final updatedList = (previous.arrearsList ?? []).where((a) => a.id != arrear.id).toList();
    employees[index] = previous.copyWith(arrearsList: updatedList);
    unawaited(_persist());

    if (arrear.backendId == null || previous.backendId == null) return;
    try {
      await _api.blockEmpArrear(
          id: arrear.backendId!, employeeId: previous.backendId!, arrearsId: arrear.backendArrearsId ?? 0);
    } catch (error) {
      trSnack('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kufuta deni "${arrear.name}" kwenye seva.');
    }
  }

  Future<void> saveArrears(String localId, List<AssignedArrear> arrearsList) async {
    final index = employees.indexWhere((e) => e.id == localId);
    if (index == -1) return;
    final previous = employees[index];

    // The employee dialogs only know the master setting's cosmetic id
    // (e.g. "ARR-001"); resolve it to the backend's numeric arrears_id here.
    final settingsById = {for (final s in Get.find<ArrearsSettingsController>().masterArrears) s.id: s};
    final resolvedList = arrearsList
        .map((a) => a.backendArrearsId != null || a.settingId == null
            ? a
            : a.copyWith(backendArrearsId: settingsById[a.settingId]?.backendId))
        .toList();

    employees[index] = previous.copyWith(arrearsList: resolvedList);
    unawaited(_persist());

    await _persistArrearsToBackend(
      localId: localId,
      employeeIdNumber: previous.employeeIdNumber,
      knownBackendEmployeeId: previous.backendId,
      previousList: previous.arrearsList,
      newList: resolvedList,
    );
  }

  /// Persists the diff between [previousList] and [newList] to the backend.
  ///
  /// Any item with no `backendArrearsId` (the person typed a one-off name
  /// instead of picking from the Master Arrears dropdown) gets a matching
  /// master `Arrears` row created on the fly first - the backend's
  /// `emp_arrears` table requires a real `arrears_id`, so a custom entry
  /// has nowhere to be stored without one. Without this, anything typed by

  /// hand would look saved in the dialog but silently vanish on the next
  /// refresh from the backend.
  /// Creates a new master `Arrears` setting for a custom, one-off entry the
  /// person typed by hand (instead of picking from the dropdown). If a
  /// setting with that exact name already exists - very likely once more
  /// than one employee gets the same custom deduction (e.g. "Ada ya Chama
  /// TUGHE") - the backend rejects the create with "already exists"; in
  /// that case we look it up and reuse its id rather than failing the
  /// whole save.
  Future<int> _resolveOrCreateArrearSettingId(AssignedArrear item) async {
    try {
      final createdSetting = await _api.saveArrearSetting(
        id: 0,
        name: item.name,
        key: 'OTHER',
        deductionModel: item.deductionType.toUpperCase(),
        percentOrAmount: item.value,
      );
      final id = (createdSetting['id'] as num?)?.toInt();
      if (id != null) return id;
    } on ApiException catch (_) {
      // Fall through to the by-name lookup below (most likely cause:
      // a setting with this name already exists).
    }
    final matches = await _api.searchArrearSettings(name: item.name.toUpperCase());
    if (matches.isNotEmpty) {
      final id = (Map<String, dynamic>.from(matches.first as Map)['id'] as num?)?.toInt();
      if (id != null) return id;
    }
    throw ApiException('Imeshindwa kutambua/kuunda aina ya kato "${item.name}".');
  }

  /// [localId] is only the local list-lookup key (cosmetic display id) -
  /// [backendEmployeeId] (resolved below, numeric) is the only employee
  /// reference ever sent to the backend.
  Future<void> _persistArrearsToBackend({
    required String localId,
    required String employeeIdNumber,
    required int? knownBackendEmployeeId,
    required List<AssignedArrear>? previousList,
    required List<AssignedArrear> newList,
  }) async {
    final backendEmployeeId = await _resolveBackendEmployeeId(knownBackendEmployeeId, employeeIdNumber);
    if (backendEmployeeId == null) {
      trSnack('Imeshindikana',
          'Huyu mfanyakazi hajapatikana kwenye seva bado. Subiri sekunde chache baada ya kumsajili, kisha jaribu tena.');
      return;
    }
    _reconcileBackendId(localId, knownBackendEmployeeId, backendEmployeeId);

    final previousBackendIds = {
      for (final a in previousList ?? const <AssignedArrear>[]) if (a.backendId != null) a.backendId!,
    };
    final keptBackendIds = <int>{};
    final finalList = <AssignedArrear>[];
    var createdNewSetting = false;

    for (var item in newList) {
      try {
        var arrearsId = item.backendArrearsId;
        if (arrearsId == null) {
          arrearsId = await _resolveOrCreateArrearSettingId(item);
          item = item.copyWith(settingId: 'ARR-$arrearsId', backendArrearsId: arrearsId);
          createdNewSetting = true;
        }
        if (arrearsId == null) throw ApiException('Imeshindwa kutambua aina ya kato hili.');

        if (item.backendId == null) {
          final created = await _api.saveEmpArrear(
              id: 0,
              amount: item.isDebtReduction ? (item.totalDebtAmount ?? item.value) : item.value,
              deduction: item.value,
              employeeId: backendEmployeeId,
              arrearsId: arrearsId,
              isDebt: item.isDebtReduction);
          item = item.copyWith(backendId: (created['id'] as num?)?.toInt());
        } else {
          await _api.saveEmpArrear(
              id: item.backendId!,
              amount: item.isDebtReduction ? (item.totalDebtAmount ?? item.value) : item.value,
              deduction: item.value,
              employeeId: backendEmployeeId,
              arrearsId: arrearsId,
              isDebt: item.isDebtReduction);
          keptBackendIds.add(item.backendId!);
        }
        finalList.add(item);
      } catch (error, stack) {
        // Show the REAL error, not a generic message - this is the fastest
        // way to pin down exactly what's failing.
        final detail = error is ApiException ? error.message : error.toString();
        // ignore: avoid_print
        print('saveArrears failed for "${item.name}": $error\n$stack');
        trSnack('Imeshindikana: ${item.name}', detail, duration: const Duration(seconds: 8));
        finalList.add(item); // keep it locally so the person doesn't lose what they typed
      }
    }

    for (final backendId in previousBackendIds.difference(keptBackendIds)) {
      final removed = previousList?.firstWhereOrNull((a) => a.backendId == backendId);
      _api
          .blockEmpArrear(id: backendId, employeeId: backendEmployeeId, arrearsId: removed?.backendArrearsId ?? 0)
          .catchError((error) => trSnack(
              'Imeshindikana', error is ApiException ? error.message : 'Imeshindwa kuondoa deni.'));
    }

    final idx = employees.indexWhere((e) => e.id == localId);
    if (idx != -1) {
      employees[idx] = employees[idx].copyWith(arrearsList: finalList);
      unawaited(_persist());
    }
    if (createdNewSetting) {
      unawaited(Get.find<ArrearsSettingsController>().refreshFromBackend());
    }
  }

  /// Same as deleteArrearNow, for allowances.
  Future<void> deleteAllowanceNow(String localId, AssignedAllowance allowance) async {
    final index = employees.indexWhere((e) => e.id == localId);
    if (index == -1) return;
    final previous = employees[index];
    final updatedList = (previous.allowancesList ?? []).where((a) => a.id != allowance.id).toList();
    employees[index] = previous.copyWith(allowancesList: updatedList);
    unawaited(_persist());

    if (allowance.backendId == null || previous.backendId == null) return;
    try {
      await _api.blockEmpAllowance(
          id: allowance.backendId!, employeeId: previous.backendId!, allowanceId: allowance.backendAllowanceId ?? 0);
    } catch (error) {
      trSnack('Imeshindikana',
          error is ApiException ? error.message : 'Imeshindwa kufuta posho "${allowance.name}" kwenye seva.');
    }
  }

  Future<void> saveAllowances(String localId, List<AssignedAllowance> allowancesList) async {
    final index = employees.indexWhere((e) => e.id == localId);
    if (index == -1) return;
    final previous = employees[index];

    final settingsById = {for (final s in Get.find<AllowancesSettingsController>().masterAllowances) s.id: s};
    final resolvedList = allowancesList
        .map((a) => a.backendAllowanceId != null || a.settingId == null
            ? a
            : a.copyWith(backendAllowanceId: settingsById[a.settingId]?.backendId))
        .toList();

    employees[index] = previous.copyWith(allowancesList: resolvedList);
    unawaited(_persist());

    await _persistAllowancesToBackend(
      localId: localId,
      employeeIdNumber: previous.employeeIdNumber,
      knownBackendEmployeeId: previous.backendId,
      previousList: previous.allowancesList,
      newList: resolvedList,
    );
  }

  /// Same as [_resolveOrCreateArrearSettingId], for allowances.
  Future<int> _resolveOrCreateAllowanceSettingId(AssignedAllowance item) async {
    try {
      final createdSetting = await _api.saveAllowanceSetting(
        id: 0,
        name: item.name,
        additionModel: item.additionType.toUpperCase(),
        allowancesType: item.isSpecial ? 'SPECIAL' : 'OTHER',
        percentOrAmount: item.value,
        isForEverOne: false,
      );
      final id = (createdSetting['id'] as num?)?.toInt();
      if (id != null) return id;
    } on ApiException catch (_) {
      // Fall through to the by-name lookup below.
    }
    final matches = await _api.searchAllowanceSettings(name: item.name.toUpperCase());
    if (matches.isNotEmpty) {
      final id = (Map<String, dynamic>.from(matches.first as Map)['id'] as num?)?.toInt();
      if (id != null) return id;
    }
    throw ApiException('Imeshindwa kutambua/kuunda aina ya posho "${item.name}".');
  }

  /// Same as [_persistArrearsToBackend], for allowances.
  Future<void> _persistAllowancesToBackend({
    required String localId,
    required String employeeIdNumber,
    required int? knownBackendEmployeeId,
    required List<AssignedAllowance>? previousList,
    required List<AssignedAllowance> newList,
  }) async {
    final backendEmployeeId = await _resolveBackendEmployeeId(knownBackendEmployeeId, employeeIdNumber);
    if (backendEmployeeId == null) {
      trSnack('Imeshindikana',
          'Huyu mfanyakazi hajapatikana kwenye seva bado. Subiri sekunde chache baada ya kumsajili, kisha jaribu tena.');
      return;
    }
    _reconcileBackendId(localId, knownBackendEmployeeId, backendEmployeeId);

    final previousBackendIds = {
      for (final a in previousList ?? const <AssignedAllowance>[]) if (a.backendId != null) a.backendId!,
    };
    final keptBackendIds = <int>{};
    final finalList = <AssignedAllowance>[];
    var createdNewSetting = false;

    for (var item in newList) {
      try {
        var allowanceId = item.backendAllowanceId;
        if (allowanceId == null) {
          allowanceId = await _resolveOrCreateAllowanceSettingId(item);
          item = item.copyWith(settingId: 'ALL-$allowanceId', backendAllowanceId: allowanceId);
          createdNewSetting = true;
        }
        if (allowanceId == null) throw ApiException('Imeshindwa kutambua aina ya posho hili.');

        if (item.backendId == null) {
          final created = await _api.saveEmpAllowance(
              id: 0, amount: item.value, employeeId: backendEmployeeId, allowanceId: allowanceId);
          item = item.copyWith(backendId: (created['id'] as num?)?.toInt());
        } else {
          await _api.saveEmpAllowance(
              id: item.backendId!, amount: item.value, employeeId: backendEmployeeId, allowanceId: allowanceId);
          keptBackendIds.add(item.backendId!);
        }
        finalList.add(item);
      } catch (error, stack) {
        final detail = error is ApiException ? error.message : error.toString();
        // ignore: avoid_print
        print('saveAllowances failed for "${item.name}": $error\n$stack');
        trSnack('Imeshindikana: ${item.name}', detail, duration: const Duration(seconds: 8));
        finalList.add(item);
      }
    }

    for (final backendId in previousBackendIds.difference(keptBackendIds)) {
      final removed = previousList?.firstWhereOrNull((a) => a.backendId == backendId);
      _api
          .blockEmpAllowance(id: backendId, employeeId: backendEmployeeId, allowanceId: removed?.backendAllowanceId ?? 0)
          .catchError((error) => trSnack(
              'Imeshindikana', error is ApiException ? error.message : 'Imeshindwa kuondoa posho.'));
    }

    final idx = employees.indexWhere((e) => e.id == localId);
    if (idx != -1) {
      employees[idx] = employees[idx].copyWith(allowancesList: finalList);
      unawaited(_persist());
    }
    if (createdNewSetting) {
      unawaited(Get.find<AllowancesSettingsController>().refreshFromBackend());
    }
  }

  String generateNextEmployeeId() {
    final numbers = employees
        .map((e) => int.tryParse(e.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final next = (numbers.isEmpty ? 0 : numbers.reduce((a, b) => a > b ? a : b)) + 1;
    return 'TGH-${next.toString().padLeft(3, '0')}';
  }
}
