/// Plain immutable model (no code generation required).
class AssignedArrear {
  const AssignedArrear({
    required this.id,
    this.settingId,
    required this.name,
    required this.deductionType,
    required this.value,
    required this.isDebtReduction,
    this.totalDebtAmount,
    this.remainingDebtAmount,
    required this.frequency,
    required this.isCreditOrDebit,
    this.backendId,
    this.backendArrearsId,
  });

  final String id;
  final String? settingId;
  final String name;
  final String deductionType; // Amount | Percent | Nothing
  final double value; // Percent or Amount
  final bool isDebtReduction; // Makato ya kupunguza deni
  final double? totalDebtAmount; // e.g. Total loan 2,000,000 TZS
  final double? remainingDebtAmount; // e.g. Remaining debt
  final String frequency; // Always | Ones
  final String isCreditOrDebit; // Credit | Debit

  /// Real numeric primary key of the `emp_arrears` row on the backend.
  final int? backendId;

  /// Real numeric primary key of the master `arrears` row this assignment
  /// points to (`tughe/empArrear/schema.py: arrears_id`).
  final int? backendArrearsId;

  AssignedArrear copyWith({
    String? id,
    String? settingId,
    String? name,
    String? deductionType,
    double? value,
    bool? isDebtReduction,
    double? totalDebtAmount,
    double? remainingDebtAmount,
    String? frequency,
    String? isCreditOrDebit,
    int? backendId,
    int? backendArrearsId,
  }) {
    return AssignedArrear(
      id: id ?? this.id,
      settingId: settingId ?? this.settingId,
      name: name ?? this.name,
      deductionType: deductionType ?? this.deductionType,
      value: value ?? this.value,
      isDebtReduction: isDebtReduction ?? this.isDebtReduction,
      totalDebtAmount: totalDebtAmount ?? this.totalDebtAmount,
      remainingDebtAmount: remainingDebtAmount ?? this.remainingDebtAmount,
      frequency: frequency ?? this.frequency,
      isCreditOrDebit: isCreditOrDebit ?? this.isCreditOrDebit,
      backendId: backendId ?? this.backendId,
      backendArrearsId: backendArrearsId ?? this.backendArrearsId,
    );
  }

  factory AssignedArrear.fromJson(Map<String, dynamic> json) => AssignedArrear(
        id: json['id'] as String,
        settingId: json['settingId'] as String?,
        name: json['name'] as String? ?? '',
        deductionType: json['deductionType'] as String? ?? 'Amount',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        isDebtReduction: json['isDebtReduction'] as bool? ?? false,
        totalDebtAmount: (json['totalDebtAmount'] as num?)?.toDouble(),
        remainingDebtAmount: (json['remainingDebtAmount'] as num?)?.toDouble(),
        frequency: json['frequency'] as String? ?? 'Always',
        isCreditOrDebit: json['isCreditOrDebit'] as String? ?? 'Debit',
        backendId: (json['backendId'] as num?)?.toInt(),
        backendArrearsId: (json['backendArrearsId'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'settingId': settingId,
        'name': name,
        'deductionType': deductionType,
        'value': value,
        'isDebtReduction': isDebtReduction,
        'totalDebtAmount': totalDebtAmount,
        'remainingDebtAmount': remainingDebtAmount,
        'frequency': frequency,
        'isCreditOrDebit': isCreditOrDebit,
        'backendId': backendId,
        'backendArrearsId': backendArrearsId,
      };

  /// Builds an assignment row from the backend's `EmpArrears` JSON
  /// (joined with its `arrears` relationship) plus the matching master
  /// setting (for the display-only fields the backend doesn't store).
  /// `isDebtReduction`/`totalDebtAmount`/`remainingDebtAmount` aren't
  /// tracked server-side yet, so they come from [previous] when available.
  factory AssignedArrear.fromBackendJson(
    Map<String, dynamic> json, {
    required String masterSettingId,
    required String name,
    required String deductionType,
    required String isCreditOrDebit,
    required String frequency,
    AssignedArrear? previous,
  }) {
    return AssignedArrear(
      id: 'EA-${json['id']}',
      backendId: (json['id'] as num?)?.toInt(),
      backendArrearsId: (json['arrears_id'] as num?)?.toInt(),
      settingId: masterSettingId,
      name: name,
      deductionType: deductionType,
      value: (json['amount'] as num?)?.toDouble() ?? 0,
      isDebtReduction: previous?.isDebtReduction ?? false,
      totalDebtAmount: previous?.totalDebtAmount,
      remainingDebtAmount: previous?.remainingDebtAmount,
      frequency: frequency,
      isCreditOrDebit: isCreditOrDebit,
    );
  }
}
