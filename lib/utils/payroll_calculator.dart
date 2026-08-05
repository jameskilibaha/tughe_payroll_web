import 'dart:math' as math;

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
      return math.max(0, totalTax.roundToDouble());
    }
  }

  // Fallback for amounts higher than the highest term's max range.
  final lastTerm = sortedTerms.last;
  if (taxableAmount > lastTerm.minSalary) {
    final excess = taxableAmount - lastTerm.minSalary;
    final taxOnExcess = (excess * lastTerm.percentage) / 100;
    return (lastTerm.additionAmount + taxOnExcess).roundToDouble();
  }

  return 0;
}

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
      totalAllowances += amount;
      allowanceDetails.add(AllowanceDetail(name: allowance.name, amount: amount.roundToDouble()));
    }
  }

  final grossSalary = basicSalary + totalAllowances;

  // Statutory pension (NSSF/PSSSF)
  final nssfDeduction = ((basicSalary * pensionRate) / 100).roundToDouble();

  // Taxable salary = Gross - Pension
  final taxableSalary = math.max(0, grossSalary - nssfDeduction).toDouble();

  // TRA PAYE Tax
  final traPayeTax = calculateTRAPayeTax(taxableSalary, terms);

  // Other arrears / deductions
  final arrearsDetails = <ArrearDetail>[];
  var totalOtherDeductions = 0.0;

  if (employee.arrearsList != null && employee.arrearsList!.isNotEmpty) {
    for (final arrear in employee.arrearsList!) {
      var amount = 0.0;
      if (arrear.deductionType == 'Amount') {
        amount = arrear.value;
      } else if (arrear.deductionType == 'Percent') {
        amount = (basicSalary * arrear.value) / 100;
      }

      if (arrear.isDebtReduction && arrear.remainingDebtAmount != null) {
        amount = math.min(amount, arrear.remainingDebtAmount!);
      }

      totalOtherDeductions += amount;
      arrearsDetails.add(ArrearDetail(
        name: arrear.name,
        amount: amount.roundToDouble(),
        isDebt: arrear.isDebtReduction,
        remaining: arrear.remainingDebtAmount != null ? arrear.remainingDebtAmount! - amount : null,
      ));
    }
  }

  final totalDeductions = nssfDeduction + traPayeTax + totalOtherDeductions;
  final netSalary = math.max(0, grossSalary - totalDeductions).toDouble();

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
