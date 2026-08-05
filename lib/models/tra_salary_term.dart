/// Plain immutable model (no code generation required).
/// TRA Formula Term (Tax Scale / Bracket)
class TRASalaryTerm {
  const TRASalaryTerm({
    required this.termNumber,
    required this.minSalary,
    required this.maxSalary,
    required this.percentage,
    required this.additionAmount,
    this.backendId,
  });

  final int termNumber; // 1 to 5
  final double minSalary; // e.g. 0
  final double maxSalary; // e.g. 270000, or a very large number for the top term
  final double percentage; // e.g. 0, 8, 20, 25, 30
  final double additionAmount; // Fixed base tax amount for the bracket

  /// Real numeric primary key of the single `salar_terms` row on the
  /// backend that holds all 5 brackets together (`tughe/salarTerm/model.py`).
  /// All 5 [TRASalaryTerm]s in a set share the same [backendId].
  final int? backendId;

  TRASalaryTerm copyWith({
    int? termNumber,
    double? minSalary,
    double? maxSalary,
    double? percentage,
    double? additionAmount,
    int? backendId,
  }) {
    return TRASalaryTerm(
      termNumber: termNumber ?? this.termNumber,
      minSalary: minSalary ?? this.minSalary,
      maxSalary: maxSalary ?? this.maxSalary,
      percentage: percentage ?? this.percentage,
      additionAmount: additionAmount ?? this.additionAmount,
      backendId: backendId ?? this.backendId,
    );
  }

  factory TRASalaryTerm.fromJson(Map<String, dynamic> json) => TRASalaryTerm(
        termNumber: (json['termNumber'] as num?)?.toInt() ?? 0,
        minSalary: (json['minSalary'] as num?)?.toDouble() ?? 0,
        maxSalary: (json['maxSalary'] as num?)?.toDouble() ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
        additionAmount: (json['additionAmount'] as num?)?.toDouble() ?? 0,
        backendId: (json['backendId'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'termNumber': termNumber,
        'minSalary': minSalary,
        'maxSalary': maxSalary,
        'percentage': percentage,
        'additionAmount': additionAmount,
        'backendId': backendId,
      };
}

/// Converts the backend's single flat `SalarTerm` row back into the 5
/// bracket rows the UI works with.
///
/// IMPORTANT: `tughe/payroll/incomeTax.py` pairs each threshold with the
/// RATE of the band that *starts* at that threshold, not the band that
/// *ends* there - e.g. the unnumbered `term`/`percentage`/`addition`
/// fields hold band 1's upper bound (270,000) together with band 2's own
/// rate (8%), not band 1's own rate (0%). Band 1 itself (the tax-free
/// band from 0 up to the first threshold) is never sent to the backend
/// explicitly - any wage below the first threshold naturally gets 0 tax
/// because no `incomeTax.py` condition matches it.
List<TRASalaryTerm> traTermsFromBackendRow(Map<String, dynamic> row) {
  final id = (row['id'] as num?)?.toInt();
  final thresholds = [
    (row['term'] as num?)?.toDouble() ?? 0,
    (row['term2'] as num?)?.toDouble() ?? 0,
    (row['term3'] as num?)?.toDouble() ?? 0,
    (row['term4'] as num?)?.toDouble() ?? 0,
    (row['term5'] as num?)?.toDouble() ?? 0,
  ];
  // Only the first 4 rate slots are needed to reconstruct bands 2-5 (the
  // 5th slot, percentage5/addition5, duplicates the top band's own rate
  // and only matters as a safety-net catch-all inside incomeTax.py).
  final percentages = [
    (row['percentage'] as num?)?.toDouble() ?? 0,
    (row['percentage2'] as num?)?.toDouble() ?? 0,
    (row['percentage3'] as num?)?.toDouble() ?? 0,
    (row['percentage4'] as num?)?.toDouble() ?? 0,
  ];
  final additions = [
    (row['addition'] as num?)?.toDouble() ?? 0,
    (row['addition2'] as num?)?.toDouble() ?? 0,
    (row['addition3'] as num?)?.toDouble() ?? 0,
    (row['addition4'] as num?)?.toDouble() ?? 0,
  ];

  final bounds = [0.0, ...thresholds]; // 6 boundary points -> 5 bands
  final result = <TRASalaryTerm>[
    TRASalaryTerm(termNumber: 1, minSalary: bounds[0], maxSalary: bounds[1], percentage: 0, additionAmount: 0, backendId: id),
  ];
  for (var k = 0; k < 4; k++) {
    result.add(TRASalaryTerm(
      termNumber: k + 2,
      minSalary: bounds[k + 1],
      maxSalary: bounds[k + 2],
      percentage: percentages[k],
      additionAmount: additions[k],
      backendId: id,
    ));
  }
  return result;
}

/// Inverse of [traTermsFromBackendRow]: flattens the 5 UI bands back into
/// the backend's single-row shape for `POST /api/salary-terms`, using the
/// same threshold/rate pairing `incomeTax.py` expects (see the note on
/// [traTermsFromBackendRow] above).
Map<String, double> traTermsToBackendFlat(List<TRASalaryTerm> terms) {
  final sorted = [...terms]..sort((a, b) => a.termNumber.compareTo(b.termNumber));
  const suffixes = ['', '2', '3', '4'];
  final flat = <String, double>{};
  for (var k = 0; k < 4 && k + 1 < sorted.length; k++) {
    flat['term${suffixes[k]}'] = sorted[k].maxSalary;
    flat['percentage${suffixes[k]}'] = sorted[k + 1].percentage;
    flat['addition${suffixes[k]}'] = sorted[k + 1].additionAmount;
  }
  if (sorted.length >= 5) {
    // Top band's own rate, duplicated as the catch-all safety net for
    // wages beyond the highest configured threshold.
    flat['term5'] = sorted[4].maxSalary;
    flat['percentage5'] = sorted[4].percentage;
    flat['addition5'] = sorted[4].additionAmount;
  }
  return flat;
}
