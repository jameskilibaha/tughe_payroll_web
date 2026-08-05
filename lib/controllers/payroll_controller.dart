import 'package:get/get.dart';

import '../network/api_exception.dart';
import '../network/api_service.dart';

/// Drives the "Endesha Payroll" (Run Payroll) screen. Talks directly to
/// `POST /api/payrolls/generate-payroll` and
/// `POST /api/payrolls/reverse-generate-payroll` (see
/// `tughe/payroll/service.py`) - unlike the Reports screen, which computes
/// its own preview locally and never touches these endpoints.
class PayrollController extends GetxController {
  PayrollController({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  final RxBool isRunning = false.obs;
  final RxnString errorMessage = RxnString();

  /// Raw JSON from the last generate/reverse call, kept as-is so the
  /// screen can show whatever shape the backend returned (employeesProcessed
  /// /employeesWithProblems/problems for generate; salarySlipsRemoved/
  /// arrearsPaymentsRemoved/allowancesPaymentsRemoved for reverse).
  final Rxn<Map<String, dynamic>> lastResult = Rxn<Map<String, dynamic>>();

  /// Which of the two actions [lastResult] belongs to - purely so the UI
  /// knows how to label/interpret it.
  final RxString lastAction = ''.obs;

  Future<bool> generate({required String monthYear, required List<int> employeeIds}) async {
    isRunning.value = true;
    errorMessage.value = null;
    try {
      final result = await _api.generatePayroll(monthYear, employeeIds: employeeIds.isEmpty ? null : employeeIds);
      lastResult.value = result;
      lastAction.value = 'generate';
      return true;
    } catch (error) {
      errorMessage.value = error is ApiException ? error.message : 'Imeshindwa kuendesha payroll.';
      return false;
    } finally {
      isRunning.value = false;
    }
  }

  Future<bool> reverse({required String monthYear, required List<int> employeeIds}) async {
    isRunning.value = true;
    errorMessage.value = null;
    try {
      final result = await _api.reverseGeneratePayroll(monthYear, employeeIds: employeeIds.isEmpty ? null : employeeIds);
      lastResult.value = result;
      lastAction.value = 'reverse';
      return true;
    } catch (error) {
      errorMessage.value = error is ApiException ? error.message : 'Imeshindwa kubatilisha payroll.';
      return false;
    } finally {
      isRunning.value = false;
    }
  }

  void clearResult() {
    lastResult.value = null;
    errorMessage.value = null;
  }
}
