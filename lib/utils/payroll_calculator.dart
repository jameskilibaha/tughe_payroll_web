import 'dart:math' as math;

import '../models/assigned_arrear.dart';
import '../models/employee.dart';
import '../models/tra_salary_term.dart';
import '../models/payroll_calculation_result.dart';
import '../models/payroll_line_item.dart';

/// Default TRA PAYE tax brackets (Tanzania Revenue Authority salary terms).
final List<TRASalaryTerm> defaultTraTerms = [
  const TRASalaryTerm(termNumber: 1, minSalary: 0, maxSalary: 270000, percentage: 0, additionAmount: 0),
  const TRASalaryTerm(termNumber: 2, minSalary: 270000, maxSalary: 520000, percentage: 8, additionAmount: 0),
  const TRASalaryTerm(termNumber: 3, minSalary: 520000, maxSalary: 760000, percentage: 20, additionAmount: 20000),
  const TRASalaryTerm(termNumber: 4, minSalary: 760000, maxSalary: 1000000, percentage: 25, additionAmount: 68000),
  const TRASalaryTerm(termNumber: 5, minSalary: 1000000, maxSalary: 999999999, percentage: 30, additionAmount: 128000),
];

/// Calculates TRA PAYE Tax based on the 5 Salary Terms/Brackets.
double calculateTRAPayeTax(double taxableAmount, List<TRASalaryTerm> traTerms) {
  if (taxableAmount <= 0) return 0;

  final sortedTerms = [...traTerms]
    ..sort((a, b) => a.termNumber.compareTo(b.termNumber));

  for (var i = 0; i < sortedTerms.length; i++) {
    final term = sortedTerms[i];
    final isLastTerm = i == sortedTerms.length - 1;

    if (taxableAmount > term.minSalary &&
        (taxableAmount <= term.maxSalary || isLastTerm)) {
      final excess = taxableAmount - term.minSalary;
      final taxOnExcess = (excess * term.percentage) / 100;
      final totalTax = term.additionAmount + taxOnExcess;
      return math.max(0, q3(totalTax));
    }
  }

  // Fallback for amounts higher than the highest term's max range.
  final lastTerm = sortedTerms.last;
  if (taxableAmount > lastTerm.minSalary) {
    final excess = taxableAmount - lastTerm.minSalary;
    final taxOnExcess = (excess * lastTerm.percentage) / 100;
    return q3(lastTerm.additionAmount + taxOnExcess);
  }

  return 0;
}

/// Exactly 3 decimal places (half up) - the same precision the server stores,
/// so the on-screen estimate matches the official payroll to the last digit.
double q3(double v) => double.parse(v.toStringAsFixed(3));

/// Full payroll calculator for a single employee.
/// pensionRate: Standard NSSF/PSSSF contribution rate (default 10%).
PayrollCalculationResult calculateEmployeePayroll(
  Employee employee, {
  List<TRASalaryTerm>? traTerms,
  double pensionRate = 10,
}) {
  final terms = traTerms ?? defaultTraTerms;
  final basicSalary = employee.salaryStatus?.basicSalary ?? 0;

  // Allowances
  final allowanceDetails = <AllowanceDetail>[];
  var totalAllowances = 0.0;

  if (employee.allowancesList != null && employee.allowancesList!.isNotEmpty) {
    for (final allowance in employee.allowancesList!) {
      var amount = 0.0;
      if (allowance.additionType == 'Amount') {
        amount = allowance.value;
      } else if (allowance.additionType == 'Percent') {
        amount = (basicSalary * allowance.value) / 100;
      }
      amount = q3(amount);
      totalAllowances += amount;
      allowanceDetails.add(AllowanceDetail(name: allowance.name, amount: amount));
    }
  }

  totalAllowances = q3(totalAllowances);
  final grossSalary = q3(basicSalary + totalAllowances);

  // (A) Statutory pension (NSSF/PSSSF): a percent of the BASIC salary. The rate
  // of the employee's "NSSF" arrear is used when present, else the standard 10%.
  var nssfRate = pensionRate;
  for (final a in employee.arrearsList ?? const <AssignedArrear>[]) {
    if (a.name.trim().toUpperCase() == 'NSSF' && a.deductionType == 'Percent') nssfRate = a.value;
  }
  final nssfDeduction = q3((basicSalary * nssfRate) / 100);

  // (B) PAYE is charged on the basic salary AFTER NSSF - allowances are added
  // afterwards (same order as the official payroll run on the server).
  final taxableSalary = q3(math.max(0, basicSalary - nssfDeduction).toDouble());

  // TRA PAYE Tax
  final traPayeTax = calculateTRAPayeTax(taxableSalary, terms);

  // Other arrears / deductions
  final arrearsDetails = <ArrearDetail>[];
  var totalOtherDeductions = 0.0;

  if (employee.arrearsList != null && employee.arrearsList!.isNotEmpty) {
    for (final arrear in employee.arrearsList!) {
      // NSSF / TRA are taken in steps (A) and (B) above - never twice.
      final upper = arrear.name.trim().toUpperCase();
      if (upper == 'NSSF' || upper == 'TRA') continue;
      var amount = 0.0;
      if (arrear.deductionType == 'Amount') {
        amount = arrear.value;
      } else if (arrear.deductionType == 'Percent') {
        amount = (basicSalary * arrear.value) / 100;
      }

      if (arrear.isDebtReduction) {
        // A debt: only the unpaid balance is taken, and nothing once it is repaid.
        final balance = arrear.remainingDebtAmount ?? arrear.totalDebtAmount ?? amount;
        if (balance <= 0) continue;
        amount = math.min(amount, balance);
      }

      amount = q3(amount);
      totalOtherDeductions += amount;
      arrearsDetails.add(ArrearDetail(
        name: arrear.name,
        amount: amount,
        isDebt: arrear.isDebtReduction,
        remaining: arrear.remainingDebtAmount != null ? arrear.remainingDebtAmount! - amount : null,
      ));
    }
  }

  totalOtherDeductions = q3(totalOtherDeductions);
  final totalDeductions = q3(nssfDeduction + traPayeTax + totalOtherDeductions);
  final netSalary = q3(math.max(0, grossSalary - totalDeductions).toDouble());

  return PayrollCalculationResult(
    employeeId: employee.id,
    employeeName: employee.fullName,
    basicSalary: basicSalary,
    totalAllowances: totalAllowances,
    grossSalary: grossSalary,
    nssfDeduction: nssfDeduction,
    taxableSalary: taxableSalary,
    traPayeTax: traPayeTax,
    totalOtherDeductions: totalOtherDeductions,
    totalDeductions: totalDeductions,
    netSalary: netSalary,
    allowanceDetails: allowanceDetails,
    arrearsDetails: arrearsDetails,
  );
}
