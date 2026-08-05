import '../models/employee.dart';
import '../models/payroll_calculation_result.dart';
import '../models/payroll_line_item.dart';

/// Builds a [PayrollCalculationResult] from real generated payroll rows
/// (`tughe/payroll/service.py: PROCESSING()` output, one row per
/// NSSF/income-tax/allowance/arrear/net-pay step). Mirrors exactly how the
/// backend computes each figure - see:
///   - NSSF: tughe/payroll/nationalBenefits.py
///   - Income tax: tughe/payroll/incomeTax.py
///   - Allowances: tughe/payroll/allowancesCalculation.py
///   - Arrears: tughe/payroll/arreasCalculate.py
PayrollCalculationResult buildResultFromGeneratedRows(Employee emp, List<Map<String, dynamic>> rows) {
  double nssfDeduction = 0;
  double traPayeTax = 0;
  double netSalary = 0;
  final allowances = <AllowanceDetail>[];
  final arrears = <ArrearDetail>[];

  for (final row in rows) {
    final process = row['process'] as String? ?? '';
    final processName = row['processName'] as String? ?? '';
    final performAmount = (row['performAmount'] as num?)?.toDouble() ?? 0;
    final total = (row['total'] as num?)?.toDouble() ?? 0;

    if (processName == 'NSSF') {
      nssfDeduction = performAmount;
    } else if (processName == 'INCOME TAX') {
      traPayeTax = performAmount;
    } else if (process == 'netPay') {
      netSalary = total;
    } else if (process == 'allowances') {
      allowances.add(AllowanceDetail(name: processName, amount: performAmount));
    } else if (process == 'arrears') {
      arrears.add(ArrearDetail(name: processName, amount: performAmount));
    }
  }

  final basicSalary = emp.salaryStatus?.basicSalary ?? 0;
  final totalAllowances = allowances.fold<double>(0, (sum, a) => sum + a.amount);
  final totalOtherDeductions = arrears.fold<double>(0, (sum, a) => sum + a.amount);
  final grossSalary = basicSalary + totalAllowances;
  final taxableSalary = basicSalary - nssfDeduction;
  final totalDeductions = nssfDeduction + traPayeTax + totalOtherDeductions;

  return PayrollCalculationResult(
    employeeId: emp.id,
    employeeName: emp.fullName,
    basicSalary: basicSalary,
    totalAllowances: totalAllowances,
    grossSalary: grossSalary,
    nssfDeduction: nssfDeduction,
    taxableSalary: taxableSalary,
    traPayeTax: traPayeTax,
    totalOtherDeductions: totalOtherDeductions,
    totalDeductions: totalDeductions,
    // Prefer the backend's own NETPAY total (most authoritative); fall
    // back to a local re-derivation only if that row was somehow missing.
    netSalary: netSalary != 0 ? netSalary : (grossSalary - totalDeductions),
    allowanceDetails: allowances,
    arrearsDetails: arrears,
  );
}
