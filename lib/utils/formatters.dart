import 'package:intl/intl.dart';

/// Every money amount in the app is shown with EXACTLY 3 decimal places and is
/// never rounded to whole shillings (the server computes with exact decimal
/// arithmetic, see tughe/payroll/money.py).
final NumberFormat _amountFormat = NumberFormat('#,##0.000', 'en_US');

/// "1,234,567.891" - an amount without currency.
String formatAmount(num amount) => _amountFormat.format(amount);

/// Formats an amount as Tanzanian Shillings, e.g. "TZS 2,200,000.000".
String formatTZS(num amount) => 'TZS ${_amountFormat.format(amount)}';

/// Plain editable text of a number (for input boxes): all its decimals up to 3,
/// without grouping or trailing zeros - 1234567.891, 25000, 7.5.
String plainAmount(num value) {
  final text = value.toStringAsFixed(3);
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Percent / share with 3 decimals, e.g. "33.333%".
String formatPercent(num value) => '${value.toStringAsFixed(3)}%';

/// Formats an ISO date string (YYYY-MM-DD) as a readable date, e.g. "12 Apr 1985".
String formatDate(String isoDate) {
  try {
    final date = DateTime.parse(isoDate);
    return DateFormat('d MMM yyyy').format(date);
  } catch (_) {
    return isoDate;
  }
}

/// Compulsory retirement age used across the Tanzania public service. If
/// your organisation uses a different age, change this in one place.
const int defaultRetirementAge = 60;

/// Computes the retirement date (as an ISO "YYYY-MM-DD" string) from a
/// date of birth, using [retirementAge] (default 60 - the standard
/// compulsory retirement age in the Tanzania public service). Returns
/// null if [dateOfBirthIso] can't be parsed.
String? computeRetirementDateIso(String dateOfBirthIso, {int retirementAge = defaultRetirementAge}) {
  try {
    final dob = DateTime.parse(dateOfBirthIso);
    final retirement = DateTime(dob.year + retirementAge, dob.month, dob.day);
    return DateFormat('yyyy-MM-dd').format(retirement);
  } catch (_) {
    return null;
  }
}
