import '../models/employee.dart';
import 'payroll_calculator.dart' show q3;
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
  // Basic salary AT THE TIME of that payroll run: the NSSF row stores the
  // wages it was calculated from (amountWas). Using it keeps old months correct
  // even if the employee's salary was changed afterwards.
  double? basicAtRun;
  double traPayeTax = 0;
  // The income PAYE was worked out on (the INCOME TAX row's amountWas): basic - pension + taxable allowances.
  double? taxableAtRun;
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
      final was = (row['amountWas'] as num?)?.toDouble();
      if (was != null && was > 0) basicAtRun = was;
    } else if (processName == 'INCOME TAX') {
      traPayeTax = performAmount;
      final base = (row['amountWas'] as num?)?.toDouble();
      if (base != null && base > 0) taxableAtRun = base;
    } else if (process == 'netPay') {
      netSalary = total;
    } else if (process == 'allowances') {
      allowances.add(AllowanceDetail(name: processName, amount: performAmount));
    } else if (process == 'arrears') {
      arrears.add(ArrearDetail(name: processName, amount: performAmount));
    }
  }

  final basicSalary = basicAtRun ?? emp.salaryStatus?.basicSalary ?? 0;
  final totalAllowances = q3(allowances.fold<double>(0, (sum, a) => sum + a.amount));
  final totalOtherDeductions = q3(arrears.fold<double>(0, (sum, a) => sum + a.amount));
  final grossSalary = q3(basicSalary + totalAllowances);
  final taxableSalary = taxableAtRun ?? q3(basicSalary - nssfDeduction);
  final totalDeductions = q3(nssfDeduction + traPayeTax + totalOtherDeductions);

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
    netSalary: netSalary != 0 ? netSalary : q3(grossSalary - totalDeductions),
    allowanceDetails: allowances,
    arrearsDetails: arrears,
  );
}
