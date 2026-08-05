import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/employee.dart';
import '../models/payroll_calculation_result.dart';
import 'formatters.dart';

const _pdfBrandBlue = PdfColor.fromInt(0xFF1E3A8A);
const _pdfEmerald = PdfColor.fromInt(0xFF065F46);
const _pdfRed = PdfColor.fromInt(0xFF991B1B);

/// Opens the browser's native print dialog (via `printing`, which works on
/// Flutter Web) with a payslip PDF built from [emp]/[calc]/[periodLabel].
Future<void> printSalarySlip({
  required Employee emp,
  required PayrollCalculationResult calc,
  required String periodLabel,
  required bool isOfficial,
}) async {
  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header(periodLabel, isOfficial),
          pw.SizedBox(height: 14),
          pw.Divider(color: _pdfBrandBlue, thickness: 1.2),
          pw.SizedBox(height: 14),
          _employeeDetails(emp),
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _earningsBox(calc)),
              pw.SizedBox(width: 16),
              pw.Expanded(child: _deductionsBox(calc)),
            ],
          ),
          pw.SizedBox(height: 16),
          _netPayBox(calc, emp),
          pw.SizedBox(height: 24),
          _footer(),
        ],
      ),
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => doc.save());
}

pw.Widget _header(String periodLabel, bool isOfficial) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('TANZANIA UNION OF GOVERNMENT AND HEALTH EMPLOYEES',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _pdfBrandBlue)),
            pw.SizedBox(height: 2),
            pw.Text('Chama cha Wafanyakazi wa Serikali na Afya Tanzania (TUGHE)',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pdfBrandBlue)),
            pw.SizedBox(height: 2),
            pw.Text('S.L.P 463, Dodoma / Dar es Salaam - Tanzania',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          ],
        ),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: pw.BoxDecoration(color: _pdfBrandBlue, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Text('SALARY SLIP / HATI YA MSHAHARA',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 4),
          pw.Text('KIPINDI: ${periodLabel.toUpperCase()}',
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
          if (!isOfficial) ...[
            pw.SizedBox(height: 4),
            pw.Text('MAKADIRIO TU - BADO HUJAENDESHA PAYROLL RASMI',
                style: pw.TextStyle(fontSize: 8, color: _pdfRed, fontWeight: pw.FontWeight.bold)),
          ],
        ],
      ),
    ],
  );
}

pw.Widget _employeeDetails(Employee emp) {
  final retirementDate = computeRetirementDateIso(emp.dateOfBirth);
  final rows = [
    ['Namba ya Mfanyakazi', emp.id],
    ['Jina Kamili', emp.fullName],
    ['Cheo / Kazi', emp.salaryStatus?.occupation ?? '-'],
    ['Kituo cha Kazi', emp.salaryStatus?.workStation ?? '-'],
    ['Jina la Benki', emp.salaryStatus?.bankName ?? '-'],
    ['Namba ya Akaunti', emp.salaryStatus?.bankAccountNumber ?? '-'],
    ['Tarehe ya Kuzaliwa', emp.dateOfBirth.isNotEmpty ? formatDate(emp.dateOfBirth) : '-'],
    ['Tarehe ya Kustaafu', retirementDate != null ? formatDate(retirementDate) : '-'],
  ];
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
    child: pw.Wrap(
      spacing: 20,
      runSpacing: 8,
      children: rows
          .map((r) => pw.SizedBox(
                width: 150,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(r[0], style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                    pw.Text(r[1], style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ))
          .toList(),
    ),
  );
}

pw.Widget _earningsBox(PayrollCalculationResult calc) {
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          color: _pdfEmerald,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text('MAPATO NA POSHO (EARNINGS)',
              style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _row('Mshahara wa Msingi', formatTZS(calc.basicSalary), bold: true),
              for (final a in calc.allowanceDetails) _row('+ ${a.name}', formatTZS(a.amount)),
              pw.Divider(color: _pdfEmerald),
              _row('MSHAHARA GHAFU (GROSS)', formatTZS(calc.grossSalary), bold: true, color: _pdfEmerald),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _deductionsBox(PayrollCalculationResult calc) {
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          color: _pdfRed,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text('MAKATO NA KODI (DEDUCTIONS)',
              style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _row('NSSF / PSSSF', formatTZS(calc.nssfDeduction), bold: true),
              _row('Kodi ya TRA (PAYE)', formatTZS(calc.traPayeTax), bold: true),
              for (final a in calc.arrearsDetails) _row('- ${a.name}', formatTZS(a.amount)),
              pw.Divider(color: _pdfRed),
              _row('JUMLA YA MAKATO', formatTZS(calc.totalDeductions), bold: true, color: _pdfRed),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _netPayBox(PayrollCalculationResult calc, Employee emp) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(color: _pdfBrandBlue, borderRadius: pw.BorderRadius.circular(8)),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('MSHAHARA SAFI (NET PAY)',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text('Akaunti: ${emp.salaryStatus?.bankName ?? '-'}',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
          ],
        ),
        pw.Text(formatTZS(calc.netSalary),
            style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget _footer() {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Inathibitishwa na:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 24),
          pw.Container(width: 150, height: 0.6, color: PdfColors.grey600),
          pw.SizedBox(height: 3),
          pw.Text('Mhasibu Mkuu wa Mshahara TUGHE', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _pdfBrandBlue), borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(
          children: [
            pw.Text('CHAMA CHA TUGHE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pdfBrandBlue)),
            pw.Text('OFFICIAL PAYROLL STAMP', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _pdfBrandBlue)),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _row(String label, String value, {bool bold = false, PdfColor? color}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      ],
    ),
  );
}
