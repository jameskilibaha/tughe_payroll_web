/// Plain immutable model (no code generation required).
class AssignedAllowance {
  const AssignedAllowance({
    required this.id,
    this.settingId,
    required this.name,
    required this.additionType,
    required this.value,
    required this.isSpecial,
    this.backendId,
    this.backendAllowanceId,
  });

  final String id;
  final String? settingId;
  final String name;
  final String additionType; // Amount | Percent
  final double value; // Amount or Percent
  final bool isSpecial;

  /// Real numeric primary key of the `emp_allowances` row on the backend.
  final int? backendId;

  /// Real numeric primary key of the master `allowances` row this
  /// assignment points to (`tughe/empAllowance/schema.py: allowance_id`).
  final int? backendAllowanceId;

  AssignedAllowance copyWith({
    String? id,
    String? settingId,
    String? name,
    String? additionType,
    double? value,
    bool? isSpecial,
    int? backendId,
    int? backendAllowanceId,
  }) {
    return AssignedAllowance(
      id: id ?? this.id,
      settingId: settingId ?? this.settingId,
      name: name ?? this.name,
      additionType: additionType ?? this.additionType,
      value: value ?? this.value,
      isSpecial: isSpecial ?? this.isSpecial,
      backendId: backendId ?? this.backendId,
      backendAllowanceId: backendAllowanceId ?? this.backendAllowanceId,
    );
  }

  factory AssignedAllowance.fromJson(Map<String, dynamic> json) => AssignedAllowance(
        id: json['id'] as String,
        settingId: json['settingId'] as String?,
        name: json['name'] as String? ?? '',
        additionType: json['additionType'] as String? ?? 'Amount',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        isSpecial: json['isSpecial'] as bool? ?? false,
        backendId: (json['backendId'] as num?)?.toInt(),
        backendAllowanceId: (json['backendAllowanceId'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'settingId': settingId,
        'name': name,
        'additionType': additionType,
        'value': value,
        'isSpecial': isSpecial,
        'backendId': backendId,
        'backendAllowanceId': backendAllowanceId,
      };

  /// Builds an assignment row from the backend's `EmpAllowances` JSON plus
  /// the matching master setting.
  factory AssignedAllowance.fromBackendJson(
    Map<String, dynamic> json, {
    required String masterSettingId,
    required String name,
    required String additionType,
    required bool isSpecial,
  }) {
    return AssignedAllowance(
      id: 'EAL-${json['id']}',
      backendId: (json['id'] as num?)?.toInt(),
      backendAllowanceId: (json['allowance_id'] as num?)?.toInt(),
      settingId: masterSettingId,
      name: name,
      additionType: additionType,
      value: (json['amount'] as num?)?.toDouble() ?? 0,
      isSpecial: isSpecial,
    );
  }
}
