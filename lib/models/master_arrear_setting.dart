/// Plain immutable model (no code generation required).
/// arrearsType: 'Special' | 'Other'
/// deductionType: 'Amount' | 'Percent' | 'Nothing'
/// isCreditOrDebit: 'Credit' | 'Debit'
/// frequency: 'Always' | 'Ones'
class MasterArrearSetting {
  const MasterArrearSetting({
    required this.id,
    required this.name,
    required this.arrearsType,
    required this.deductionType,
    required this.defaultValue,
    required this.isCreditOrDebit,
    required this.frequency,
    this.description,
    this.backendId,
  });

  final String id;
  final String name; // e.g. Kato la TUGHE, Mkopo wa HESLB, Saccos
  final String arrearsType;
  final String deductionType;
  final double defaultValue; // Percent or Amount
  final String isCreditOrDebit;
  final String frequency;
  final String? description;

  /// Real numeric primary key from the backend (`tughe/arrear/model.py`).
  /// The backend table doesn't (yet) have columns for isCreditOrDebit,
  /// frequency or description, so those three stay locally-cached,
  /// merged back in by id whenever this list is refreshed from the API.
  final int? backendId;

  MasterArrearSetting copyWith({
    String? id,
    String? name,
    String? arrearsType,
    String? deductionType,
    double? defaultValue,
    String? isCreditOrDebit,
    String? frequency,
    String? description,
    int? backendId,
  }) {
    return MasterArrearSetting(
      id: id ?? this.id,
      name: name ?? this.name,
      arrearsType: arrearsType ?? this.arrearsType,
      deductionType: deductionType ?? this.deductionType,
      defaultValue: defaultValue ?? this.defaultValue,
      isCreditOrDebit: isCreditOrDebit ?? this.isCreditOrDebit,
      frequency: frequency ?? this.frequency,
      description: description ?? this.description,
      backendId: backendId ?? this.backendId,
    );
  }

  factory MasterArrearSetting.fromJson(Map<String, dynamic> json) => MasterArrearSetting(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        arrearsType: json['arrearsType'] as String? ?? 'Special',
        deductionType: json['deductionType'] as String? ?? 'Percent',
        defaultValue: (json['defaultValue'] as num?)?.toDouble() ?? 0,
        isCreditOrDebit: json['isCreditOrDebit'] as String? ?? 'Debit',
        frequency: json['frequency'] as String? ?? 'Always',
        description: json['description'] as String?,
        backendId: (json['backendId'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'arrearsType': arrearsType,
        'deductionType': deductionType,
        'defaultValue': defaultValue,
        'isCreditOrDebit': isCreditOrDebit,
        'frequency': frequency,
        'description': description,
        'backendId': backendId,
      };

  /// Maps the backend's `Arrears` schema onto this model. `isCreditOrDebit`,
  /// `frequency` and `description` aren't stored server-side, so they're
  /// taken from [previous] (the locally-cached copy of the same setting)
  /// when available, defaulting otherwise.
  factory MasterArrearSetting.fromBackendJson(Map<String, dynamic> json, {MasterArrearSetting? previous}) {
    final key = (json['key'] as String? ?? 'OTHER').toUpperCase();
    final deductionModel = (json['deductionModel'] as String? ?? 'AMOUNT').toUpperCase();
    return MasterArrearSetting(
      id: previous?.id ?? 'ARR-${json['id']}',
      backendId: (json['id'] as num?)?.toInt(),
      name: json['name'] as String? ?? '',
      arrearsType: key == 'SPECIAL' ? 'Special' : 'Other',
      deductionType: deductionModel == 'PERCENT' ? 'Percent' : (deductionModel == 'NOTHING' ? 'Nothing' : 'Amount'),
      defaultValue: (json['percentOrAmount'] as num?)?.toDouble() ?? 0,
      isCreditOrDebit: previous?.isCreditOrDebit ?? 'Debit',
      frequency: previous?.frequency ?? 'Always',
      description: previous?.description,
    );
  }
}
