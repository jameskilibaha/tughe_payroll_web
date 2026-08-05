/// Plain immutable model (no code generation required).
class SalaryStatus {
  const SalaryStatus({
    required this.occupation,
    required this.workStation,
    required this.basicSalary,
    required this.bankName,
    required this.bankAccountNumber,
  });

  final String occupation; // e.g. Afisa Utawala, Daktari, Mhasibu
  final String workStation; // e.g. Makao Makuu Dodoma, Muhimbili
  final double basicSalary; // TZS
  final String bankName; // e.g. NMB Bank, CRDB Bank, NBC
  final String bankAccountNumber;

  SalaryStatus copyWith({
    String? occupation,
    String? workStation,
    double? basicSalary,
    String? bankName,
    String? bankAccountNumber,
  }) {
    return SalaryStatus(
      occupation: occupation ?? this.occupation,
      workStation: workStation ?? this.workStation,
      basicSalary: basicSalary ?? this.basicSalary,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
    );
  }

  factory SalaryStatus.fromJson(Map<String, dynamic> json) => SalaryStatus(
        occupation: json['occupation'] as String? ?? '',
        workStation: json['workStation'] as String? ?? '',
        basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? 0,
        bankName: json['bankName'] as String? ?? '',
        bankAccountNumber: json['bankAccountNumber'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'occupation': occupation,
        'workStation': workStation,
        'basicSalary': basicSalary,
        'bankName': bankName,
        'bankAccountNumber': bankAccountNumber,
      };
}
