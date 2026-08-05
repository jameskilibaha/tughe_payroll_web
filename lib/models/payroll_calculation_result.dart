import 'payroll_line_item.dart';

/// Plain immutable model (no code generation required).
class PayrollCalculationResult {
  const PayrollCalculationResult({
    required this.employeeId,
    required this.employeeName,
    required this.basicSalary,
    required this.totalAllowances,
    required this.grossSalary,
    required this.nssfDeduction,
    required this.taxableSalary,
    required this.traPayeTax,
    required this.totalOtherDeductions,
    required this.totalDeductions,
    required this.netSalary,
    required this.allowanceDetails,
    required this.arrearsDetails,
  });

  final String employeeId;
  final String employeeName;
  final double basicSalary;
  final double totalAllowances;
  final double grossSalary;
  final double nssfDeduction; // Statutory NSSF / PSSSF (10%)
  final double taxableSalary; // Gross - NSSF
  final double traPayeTax; // TRA Tax using the 5 Terms
  final double totalOtherDeductions;
  final double totalDeductions;
  final double netSalary;
  final List<AllowanceDetail> allowanceDetails;
  final List<ArrearDetail> arrearsDetails;

  factory PayrollCalculationResult.fromJson(Map<String, dynamic> json) => PayrollCalculationResult(
        employeeId: json['employeeId'] as String,
        employeeName: json['employeeName'] as String? ?? '',
        basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? 0,
        totalAllowances: (json['totalAllowances'] as num?)?.toDouble() ?? 0,
        grossSalary: (json['grossSalary'] as num?)?.toDouble() ?? 0,
        nssfDeduction: (json['nssfDeduction'] as num?)?.toDouble() ?? 0,
        taxableSalary: (json['taxableSalary'] as num?)?.toDouble() ?? 0,
        traPayeTax: (json['traPayeTax'] as num?)?.toDouble() ?? 0,
        totalOtherDeductions: (json['totalOtherDeductions'] as num?)?.toDouble() ?? 0,
        totalDeductions: (json['totalDeductions'] as num?)?.toDouble() ?? 0,
        netSalary: (json['netSalary'] as num?)?.toDouble() ?? 0,
        allowanceDetails: (json['allowanceDetails'] as List<dynamic>? ?? [])
            .map((e) => AllowanceDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
        arrearsDetails: (json['arrearsDetails'] as List<dynamic>? ?? [])
            .map((e) => ArrearDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'basicSalary': basicSalary,
        'totalAllowances': totalAllowances,
        'grossSalary': grossSalary,
        'nssfDeduction': nssfDeduction,
        'taxableSalary': taxableSalary,
        'traPayeTax': traPayeTax,
        'totalOtherDeductions': totalOtherDeductions,
        'totalDeductions': totalDeductions,
        'netSalary': netSalary,
        'allowanceDetails': allowanceDetails.map((e) => e.toJson()).toList(),
        'arrearsDetails': arrearsDetails.map((e) => e.toJson()).toList(),
      };
}
