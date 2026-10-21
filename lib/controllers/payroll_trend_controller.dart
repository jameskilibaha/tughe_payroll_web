import 'dart:async';

import 'package:get/get.dart';

import '../network/api_exception.dart';
import '../network/api_service.dart';

/// Payroll totals of ONE month, summed over every employee processed in it.
class MonthTotals {
  const MonthTotals({
    required this.monthYear,
    required this.employees,
    required this.net,
    required this.gross,
    required this.nssf,
    required this.paye,
    required this.allowances,
    required this.arrears,
  });

  final String monthYear; // "YYYY-MM"
  final int employees;
  final double net;
  final double gross;
  final double nssf;
  final double paye;
  final double allowances;
  final double arrears;

  int get month => int.parse(monthYear.split('-')[1]);
}

/// Totals of the last few months, for the dashboard trend charts. Loaded once
/// (one request per month, in parallel) and refreshed after a payroll run/reversal.
class PayrollTrendController extends GetxController {
  PayrollTrendController({ApiService? apiService}) : _api = apiService ?? Get.find<ApiService>();

  final ApiService _api;

  final RxList<MonthTotals> months = <MonthTotals>[].obs;
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  bool _requested = false;
  int _seq = 0;

  /// The last [count] months ending with the current one, oldest first.
  static List<String> lastMonths(int count) {
    final now = DateTime.now();
    return [
      for (var i = count - 1; i >= 0; i--)
        () {
          final d = DateTime(now.year, now.month - i);
          return '${d.year}-${d.month.toString().padLeft(2, '0')}';
        }()
    ];
  }

  Future<void> load({int count = 6, bool force = false}) async {
    if (_requested && !force) return;
    _requested = true;
    final seq = ++_seq;
    isLoading.value = true;
    error.value = '';
    try {
      final keys = lastMonths(count);
      final results = await Future.wait(keys.map((k) => _api.searchSalarySlipGeneByMonth(k)));
      if (seq != _seq) return;
      months.assignAll([for (var i = 0; i < keys.length; i++) _total(keys[i], results[i])]);
    } catch (e) {
      if (seq != _seq) return;
      _requested = false; // allow a retry on the next dashboard visit
      error.value = e is ApiException ? e.message : 'Imeshindwa kupakua mwenendo wa payroll.';
    } finally {
      if (seq == _seq) isLoading.value = false;
    }
  }

  /// Forget the cached months (call after a payroll run or reversal).
  void invalidate() {
    _seq++;
    _requested = false;
    months.clear();
    isLoading.value = false;
  }

  static MonthTotals _total(String monthYear, List<dynamic> employees) {
    double net = 0, nssf = 0, paye = 0, allowances = 0, arrears = 0, basic = 0;
    for (final item in employees) {
      final slips = (Map<String, dynamic>.from(item as Map)['slips'] as List);
      for (final raw in slips) {
        final row = Map<String, dynamic>.from(raw as Map);
        final process = row['process'] as String? ?? '';
        final name = row['processName'] as String? ?? '';
        final perform = (row['performAmount'] as num?)?.toDouble() ?? 0;
        final total = (row['total'] as num?)?.toDouble() ?? 0;
        if (name == 'NSSF') {
          nssf += perform;
          basic += (row['amountWas'] as num?)?.toDouble() ?? 0;
        } else if (name == 'INCOME TAX') {
          paye += perform;
        } else if (process == 'netPay') {
          net += total;
        } else if (process == 'allowances') {
          allowances += perform;
        } else if (process == 'arrears') {
          arrears += perform;
        }
      }
    }
    return MonthTotals(
      monthYear: monthYear,
      employees: employees.length,
      net: net,
      gross: basic + allowances,
      nssf: nssf,
      paye: paye,
      allowances: allowances,
      arrears: arrears,
    );
  }
}
