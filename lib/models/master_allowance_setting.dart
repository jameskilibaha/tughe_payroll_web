/// Plain immutable model (no code generation required).
/// allowanceType: 'Special' | 'Other'
/// additionType: 'Amount' | 'Percent'
class MasterAllowanceSetting {
  const MasterAllowanceSetting({
    required this.id,
    required this.name,
    required this.allowanceType,
    required this.additionType,
    required this.defaultValue,
    required this.isForEveryone,
    this.isTaxable = false,
    this.description,
    this.backendId,
  });

  final String id;
  final String name; // e.g. Posho ya Nyumba, Posho ya Usafiri
  final String allowanceType;
  final String additionType;
  final double defaultValue; // Amount or Percent
  final bool isForEveryone;

  /// Part of the income PAYE is worked out on (housing, ...) - or added after tax (false).
  final bool isTaxable;
  final String? description;

  /// Real numeric primary key from the backend (`tughe/allowance/model.py`).
  /// The backend table doesn't have a `description` column, so it stays
  /// locally-cached, merged back in by id on refresh.
  final int? backendId;

  MasterAllowanceSetting copyWith({
    String? id,
    String? name,
    String? allowanceType,
    String? additionType,
    double? defaultValue,
    bool? isForEveryone,
    bool? isTaxable,
    String? description,
    int? backendId,
  }) {
    return MasterAllowanceSetting(
      id: id ?? this.id,
      name: name ?? this.name,
      allowanceType: allowanceType ?? this.allowanceType,
      additionType: additionType ?? this.additionType,
      defaultValue: defaultValue ?? this.defaultValue,
      isForEveryone: isForEveryone ?? this.isForEveryone,
      isTaxable: isTaxable ?? this.isTaxable,
      description: description ?? this.description,
      backendId: backendId ?? this.backendId,
    );
  }

  factory MasterAllowanceSetting.fromJson(Map<String, dynamic> json) => MasterAllowanceSetting(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        allowanceType: json['allowanceType'] as String? ?? 'Special',
        additionType: json['additionType'] as String? ?? 'Amount',
        defaultValue: (json['defaultValue'] as num?)?.toDouble() ?? 0,
        isForEveryone: json['isForEveryone'] as bool? ?? false,
        isTaxable: json['isTaxable'] as bool? ?? false,
        description: json['description'] as String?,
        backendId: (json['backendId'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'allowanceType': allowanceType,
        'additionType': additionType,
        'defaultValue': defaultValue,
        'isForEveryone': isForEveryone,
        'isTaxable': isTaxable,
        'description': description,
        'backendId': backendId,
      };

  /// Maps the backend's `Allowance` schema onto this model. `description`
  /// isn't stored server-side, so it's carried over from [previous].
  factory MasterAllowanceSetting.fromBackendJson(Map<String, dynamic> json, {MasterAllowanceSetting? previous}) {
    final type = (json['allowancesType'] as String? ?? 'OTHER').toUpperCase();
    final model = (json['additionModel'] as String? ?? 'AMOUNT').toUpperCase();
    return MasterAllowanceSetting(
      id: previous?.id ?? 'ALL-${json['id']}',
      backendId: (json['id'] as num?)?.toInt(),
      name: json['name'] as String? ?? '',
      allowanceType: type == 'SPECIAL' ? 'Special' : 'Other',
      additionType: model == 'PERCENT' ? 'Percent' : 'Amount',
      defaultValue: (json['percentOrAmount'] as num?)?.toDouble() ?? 0,
      isForEveryone: json['isForEverOne'] as bool? ?? false,
      isTaxable: json['isTaxable'] as bool? ?? false,
      description: previous?.description,
    );
  }
}
