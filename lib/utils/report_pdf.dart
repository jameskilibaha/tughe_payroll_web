import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'logo_asset.dart';

const _blue = PdfColor.fromInt(0xFF1E3A8A);
const _slate = PdfColor.fromInt(0xFF0F172A);
const _amber = PdfColor.fromInt(0xFFFBBF24);
const _headFill = PdfColor.fromInt(0xFFE2E8F0);
const _zebra = PdfColor.fromInt(0xFFF8FAFC);

String _cell(Object? v) {
  if (v == null) return '';
  if (v is num) return NumberFormat('#,##0.000', 'en_US').format(v);
  return v.toString();
}

/// Opens the browser's print dialog (Flutter Web) / saves as PDF with ONE report:
/// landscape A4, title and period on every page, a zebra table, a TOTALS row
/// and "Page x / y" in the footer.
///
/// [rows] / [totals] hold raw values: numbers are formatted with thousands
/// separators and right-aligned, everything else is printed as text.
Future<void> printReportPdf({
  required String title,
  required String periodLabel,
  required List<String> headers,
  required List<List<Object?>> rows,
  List<Object?>? totals,
  String? filterNote,
}) async {
  final doc = pw.Document();
  final logoBytes = await loadTugheLogoBytes();
  final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);

  // A column is numeric when every non-empty value in it is a number.
  final numeric = List<bool>.generate(headers.length, (c) {
    var any = false;
    for (final r in rows) {
      if (c >= r.length) continue;
      final v = r[c];
      if (v == null || (v is String && v.isEmpty)) continue;
      if (v is! num) return false;
      any = true;
    }
    return any;
  });

  pw.Widget text(String s, {bool bold = false, PdfColor? color, bool right = false, double size = 7.6}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(s,
            style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      );

  pw.TableRow headRow() => pw.TableRow(
        decoration: const pw.BoxDecoration(color: _headFill),
        children: [for (var i = 0; i < headers.length; i++) text(headers[i], bold: true, right: numeric[i], size: 7.4)],
      );

  final bodyRows = <pw.TableRow>[
    for (var r = 0; r < rows.length; r++)
      pw.TableRow(
        decoration: r.isOdd ? const pw.BoxDecoration(color: _zebra) : null,
        children: [
          for (var c = 0; c < headers.length; c++)
            text(c < rows[r].length ? _cell(rows[r][c]) : '', right: numeric[c]),
        ],
      ),
  ];

  final totalRow = totals == null
      ? null
      : pw.TableRow(
          decoration: const pw.BoxDecoration(color: _slate),
          children: [
            for (var c = 0; c < headers.length; c++)
              text(c < totals.length ? _cell(totals[c]) : '', bold: true, color: _amber, right: numeric[c]),
          ],
        );

  final stamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 28),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // The logo stands on BOTH sides of the title (left and right).
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              logo != null ? pw.Image(logo, width: 44, height: 44, fit: pw.BoxFit.contain) : pw.SizedBox(width: 44, height: 44),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text('TANZANIA UNION OF GOVERNMENT AND HEALTH EMPLOYEES (TUGHE)',
                        textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _blue)),
                    pw.SizedBox(height: 3),
                    pw.Text(title, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              logo != null ? pw.Image(logo, width: 44, height: 44, fit: pw.BoxFit.contain) : pw.SizedBox(width: 44, height: 44),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(periodLabel.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _blue)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Rekodi: ${rows.length}', style: const pw.TextStyle(fontSize: 8)),
                  if (filterNote != null && filterNote.isNotEmpty) pw.Text(filterNote, style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: _blue, thickness: 1),
          pw.SizedBox(height: 4),
        ],
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Imetolewa: $stamp - Mfumo wa Mishahara TUGHE', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.Text('Ukurasa ${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7.5)),
        ],
      ),
      build: (context) => [
        if (rows.isEmpty)
          pw.Padding(padding: const pw.EdgeInsets.all(30), child: pw.Center(child: pw.Text('Hakuna rekodi zinazolingana.')))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            children: [headRow(), ...bodyRows, if (totalRow != null) totalRow],
          ),
      ],
    ),
  );

  await Printing.layoutPdf(
    name: '${title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${periodLabel.replaceAll(' ', '_')}.pdf',
    onLayout: (format) async => doc.save(),
  );
}
