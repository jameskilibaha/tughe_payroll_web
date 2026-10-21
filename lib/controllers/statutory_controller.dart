import 'package:get/get.dart';

import '../network/api_exception.dart';
import '../network/api_service.dart';

/// Statutory side of payroll (Tanzania): the rates, each employee's statutory details, the one-off
/// pay adjustments of a month, and the statutory reports. Everything is read from and saved to
/// the server (`/api/statutory/...`); nothing is calculated here.
class StatutoryController extends GetxController {
  StatutoryController({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  // ---- the rates ----
  final Rxn<Map<String, dynamic>> settings = Rxn<Map<String, dynamic>>();
  final RxBool loadingSettings = false.obs;
  final RxnString settingsError = RxnString();

  // ---- the report of a month ----
  final Rxn<Map<String, dynamic>> report = Rxn<Map<String, dynamic>>();
  final RxBool loadingReport = false.obs;
  final RxnString reportError = RxnString();

  // ---- the adjustments of a month ----
  final RxList<Map<String, dynamic>> adjustments = <Map<String, dynamic>>[].obs;
  final RxBool loadingAdjustments = false.obs;
  final RxnString adjustmentsError = RxnString();

  String _msg(Object e) => e is ApiException ? e.message : e.toString();

  /// True when the rates were confirmed by a person (unconfirmed rates are the program's starting values).
  bool get ratesConfirmed => settings.value?['verified'] == true;

  Future<void> loadSettings() async {
    loadingSettings.value = true;
    try {
      settings.value = await _api.statutorySettings();
      settingsError.value = null;
    } catch (e) {
      settingsError.value = _msg(e);
    } finally {
      loadingSettings.value = false;
    }
  }

  /// Saves the rates; returns null on success or the reason it failed.
  Future<String?> saveSettings(Map<String, dynamic> body) async {
    try {
      settings.value = await _api.saveStatutorySettings(body);
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  Future<String?> confirmSettings() async {
    try {
      settings.value = await _api.confirmStatutorySettings();
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  Future<void> loadReport(String month) async {
    loadingReport.value = true;
    try {
      report.value = await _api.statutoryReport(month);
      reportError.value = null;
    } catch (e) {
      report.value = null;
      reportError.value = _msg(e);
    } finally {
      loadingReport.value = false;
    }
  }

  Future<void> loadAdjustments(String month) async {
    loadingAdjustments.value = true;
    try {
      final list = await _api.payAdjustments(month);
      adjustments.assignAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      adjustmentsError.value = null;
    } catch (e) {
      adjustments.clear();
      adjustmentsError.value = _msg(e);
    } finally {
      loadingAdjustments.value = false;
    }
  }

  /// Adds an adjustment; null on success, otherwise the reason (shown to the person).
  Future<String?> addAdjustment(Map<String, dynamic> body) async {
    try {
      await _api.addPayAdjustment(body);
      await loadAdjustments(body['monthYear'] as String);
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  Future<String?> deleteAdjustment(int id, String month) async {
    try {
      await _api.deletePayAdjustment(id);
      await loadAdjustments(month);
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  // ---- the state of a payroll month (open / submitted / closed) ----
  final Rxn<Map<String, dynamic>> period = Rxn<Map<String, dynamic>>();
  final RxBool loadingPeriod = false.obs;
  final RxBool emailReady = false.obs;

  Future<void> loadPeriod(String month) async {
    loadingPeriod.value = true;
    try {
      period.value = await _api.payrollPeriod(month);
    } catch (_) {
      period.value = null;
    } finally {
      loadingPeriod.value = false;
    }
    try {
      emailReady.value = (await _api.notifyStatus())['email'] == true;
    } catch (_) {
      emailReady.value = false;
    }
  }

  /// submit | return | close | reopen. Null on success, otherwise the server's reason.
  Future<String?> periodAction(String month, String action, {String? note}) async {
    try {
      period.value = await _api.payrollPeriodAction(month, action, note: note);
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  Future<Map<String, dynamic>> sendPayslips(String month) => _api.sendPayslips(month);

  // ---- variance against the month before ----
  final Rxn<Map<String, dynamic>> variance = Rxn<Map<String, dynamic>>();
  final RxBool loadingVariance = false.obs;
  final RxnString varianceError = RxnString();

  Future<void> loadVariance(String month) async {
    loadingVariance.value = true;
    try {
      variance.value = await _api.statutoryVariance(month);
      varianceError.value = null;
    } catch (e) {
      variance.value = null;
      varianceError.value = _msg(e);
    } finally {
      loadingVariance.value = false;
    }
  }

  Future<List<Map<String, dynamic>>> salaryHistory(int employeeId) async {
    try {
      return (await _api.salaryHistory(employeeId)).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return const [];
    }
  }

  // ---- bulk import of employees ----
  Future<Map<String, dynamic>> importTemplate() => _api.importTemplate();
  Future<Map<String, dynamic>> importPreview(String filename, String b64) => _api.importPreview(filename, b64);
  Future<Map<String, dynamic>> importApply(String filename, String b64) => _api.importApply(filename, b64);

  Future<Map<String, dynamic>?> employeeProfile(int employeeId) async {
    try {
      return await _api.statutoryEmployee(employeeId);
    } catch (_) {
      return null;
    }
  }

  Future<String?> saveEmployeeProfile(int employeeId, Map<String, dynamic> body) async {
    try {
      await _api.saveStatutoryEmployee(employeeId, body);
      return null;
    } catch (e) {
      return _msg(e);
    }
  }
}
