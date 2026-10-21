import 'package:get/get.dart';

import '../network/api_exception.dart';
import '../network/api_service.dart';

/// Who was processed in the payroll run of a given month, and their generated
/// slip rows. Shared by the Salary Slip and Reports screens so that choosing a
/// month/year lists only the people who actually have payroll for it.
class MonthPayrollController extends GetxController {
  MonthPayrollController({ApiService? apiService}) : _api = apiService ?? Get.find<ApiService>();

  final ApiService _api;

  /// The "YYYY-MM" the data below belongs to ('' = nothing loaded yet).
  final RxString loadedFor = ''.obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  /// backend employee id -> that employee's generated slip rows for [loadedFor].
  final RxMap<int, List<Map<String, dynamic>>> byEmployee = <int, List<Map<String, dynamic>>>{}.obs;

  int _seq = 0;

  /// Loads the month once; calling it again for the same month is a no-op
  /// (use [force] to retry). A slow response for an older month can never
  /// overwrite the month that is selected now.
  Future<void> load(String monthYear, {bool force = false}) async {
    if (!force && loadedFor.value == monthYear) return;
    loadedFor.value = monthYear;
    final seq = ++_seq;
    isLoading.value = true;
    error.value = '';
    byEmployee.clear();
    try {
      final res = await _api.searchSalarySlipGeneByMonth(monthYear);
      if (seq != _seq) return;
      final map = <int, List<Map<String, dynamic>>>{};
      for (final item in res) {
        final m = Map<String, dynamic>.from(item as Map);
        final id = (m['employee_id'] as num).toInt();
        map[id] = (m['slips'] as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      }
      byEmployee.assignAll(map);
    } catch (e) {
      if (seq != _seq) return;
      error.value = e is ApiException ? e.message : 'Imeshindwa kupakua orodha ya payroll ya kipindi hiki.';
    } finally {
      if (seq == _seq) isLoading.value = false;
    }
  }

  /// Forget the cached month so the next [load] fetches fresh data.
  void invalidate() {
    _seq++;
    loadedFor.value = '';
    byEmployee.clear();
    isLoading.value = false;
  }

  /// True once [monthYear] has been loaded and at least one employee was processed.
  bool hasData(String monthYear) => loadedFor.value == monthYear && byEmployee.isNotEmpty;
}
