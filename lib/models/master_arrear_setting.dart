/// Plain immutable model (no code generation required).
/// Maps 1:1 onto the backend's `Arrears` schema (`tughe/arrear/model.py`,
/// `tughe/arrear/schema.py`):
///
///   arrearsType: 'Special' | 'Other' -> backend `key` ('SPECIAL' auto-
///     assigns this deduction to every employee; 'Other' is assigned
///     manually per employee).
///   deductionType: 'Amount' | 'Percent' | 'Nothing' -> backend `deductionModel`.
///   defaultValue -> backend `percentOrAmount`.
///   isPermanentDeduction -> backend `isPermanentDeduction`. Drives
///     Credit/Debit status at calculation time (see
///     `tughe/payroll/arrearsBehaviour.py::ifAmountHavCreditDebit`):
///       true  = "Credit & Debit" (a declining-balance deduction, e.g. a
///               loan, tracked against amount owed - keeps being deducted
///               until the debt is fully paid off).
///       false = "Credit" only (a flat addition/deduction, no balance
///               tracked).
///   isChoice -> backend `isChoice` ("Marudio"/recurrence):
///       true  = Daima (Always)
///       false = Mara Moja (Ones)
class MasterArrearSetting {
  const MasterArrearSetting({
    required this.id,
    required this.name,
    required this.arrearsType,
    required this.deductionType,
    required this.defaultValue,
    required this.isPermanentDeduction,
    required this.isChoice,
    this.description,
    this.backendId,
  });

  final String id;
  final String name; // e.g. Kato la TUGHE, Mkopo wa HESLB, Saccos
  final String arrearsType;
  final String deductionType;
  final double defaultValue; // Percent or Amount
  final bool isPermanentDeduction; // Credit & Debit (true) | Credit (false)
  final bool isChoice; // Marudio: Daima/Always (true) | Mara Moja/Ones (false)
  final String? description;

  /// Real numeric primary key from the backend (`tughe/arrear/model.py`).
  /// `description` isn't stored server-side, so it stays locally-cached,
  /// merged back in by id whenever this list is refreshed from the API.
  final int? backendId;

  /// Display label for the Credit/Debit field - see class doc.
  String get creditDebitLabel => isPermanentDeduction ? 'Credit & Debit' : 'Credit';

  /// Display label for the Marudio (recurrence) field - see class doc.
  String get frequencyLabel => isChoice ? 'Daima (Always)' : 'Mara Moja (Ones)';

  MasterArrearSetting copyWith({
    String? id,
    String? name,
    String? arrearsType,
    String? deductionType,
    double? defaultValue,
    bool? isPermanentDeduction,
    bool? isChoice,
    String? description,
    int? backendId,
  }) {
    return MasterArrearSetting(
      id: id ?? this.id,
      name: name ?? this.name,
      arrearsType: arrearsType ?? this.arrearsType,
      deductionType: deductionType ?? this.deductionType,
      defaultValue: defaultValue ?? this.defaultValue,
      isPermanentDeduction: isPermanentDeduction ?? this.isPermanentDeduction,
      isChoice: isChoice ?? this.isChoice,
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
        isPermanentDeduction: json['isPermanentDeduction'] as bool? ?? false,
        isChoice: json['isChoice'] as bool? ?? true,
        description: json['description'] as String?,
        backendId: (json['backendId'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'arrearsType': arrearsType,
        'deductionType': deductionType,
        'defaultValue': defaultValue,
        'isPermanentDeduction': isPermanentDeduction,
        'isChoice': isChoice,
        'description': description,
        'backendId': backendId,
      };

  /// Maps the backend's `Arrears` schema onto this model. `description`
  /// isn't stored server-side, so it's taken from [previous] (the
  /// locally-cached copy of the same setting) when available.
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
      isPermanentDeduction: json['isPermanentDeduction'] as bool? ?? false,
      isChoice: json['isChoice'] as bool? ?? true,
      description: previous?.description,
    );
  }
}
