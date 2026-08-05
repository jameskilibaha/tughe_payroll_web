import 'package:intl/intl.dart';

/// Formats an amount as Tanzanian Shillings, e.g. "TZS 2,200,000".
String formatTZS(num amount) {
  final formatter = NumberFormat.decimalPattern('en_US');
  return 'TZS ${formatter.format(amount.round())}';
}

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
