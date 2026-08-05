/// Plain immutable models (no code generation required).
/// Detail line items used inside PayrollCalculationResult.
class AllowanceDetail {
  const AllowanceDetail({required this.name, required this.amount});

  final String name;
  final double amount;

  factory AllowanceDetail.fromJson(Map<String, dynamic> json) => AllowanceDetail(
        name: json['name'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'name': name, 'amount': amount};
}

class ArrearDetail {
  const ArrearDetail({
    required this.name,
    required this.amount,
    this.isDebt,
    this.remaining,
  });

  final String name;
  final double amount;
  final bool? isDebt;
  final double? remaining;

  factory ArrearDetail.fromJson(Map<String, dynamic> json) => ArrearDetail(
        name: json['name'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        isDebt: json['isDebt'] as bool?,
        remaining: (json['remaining'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'isDebt': isDebt,
        'remaining': remaining,
      };
}
