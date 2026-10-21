import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import '../models/audit_log_entry.dart';

/// Generic CSV download helper for the browser (used by both the Audit Log
/// export and the Reports page exports). Web-only (uses dart:html), which
/// matches this project's Flutter Web target.
void downloadCsv({
  required String filename,
  required List<String> headers,
  required List<List<Object?>> rows,
}) {
  // Money amounts are written with exactly 3 decimals (no floating-point noise,
  // no rounding to whole shillings); integers (counts, ids) stay as they are.
  String text(Object? value) => value is double ? value.toStringAsFixed(3) : (value ?? '').toString();
  String esc(Object? value) => '"${text(value).replaceAll('"', '""')}"';

  final buffer = StringBuffer()..writeln(headers.map(esc).join(','));
  for (final row in rows) {
    buffer.writeln(row.map(esc).join(','));
  }

  // UTF-8 BOM so Excel opens the file with the right encoding (Swahili text,
  // symbols) instead of garbling it. Real typed bytes: a plain Dart list of numbers
  // would be written into the file as the text "239,187,191,...".
  final bytes = Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);
  saveBytesAs(filename: filename, bytes: bytes, mime: 'text/csv;charset=utf-8');
}

/// Hands [bytes] to the browser as a download called [filename].
///
/// The link is put in the page while it is clicked (Firefox and Edge ignore a link that is not
/// in the page), and the temporary file address is released only after a minute - releasing it
/// at once cancels the download of a large file ("Failed - Network error").
void saveBytesAs({required String filename, required Uint8List bytes, String mime = 'application/octet-stream'}) {
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(minutes: 1), () => html.Url.revokeObjectUrl(url));
}

/// Exports audit log entries as a downloadable CSV file in the browser.
/// Mirrors `handleExportAuditLogs` from the original SettingsUserController.tsx.
void exportAuditLogsCsv(List<AuditLogEntry> logs) {
  final dateStamp = DateTime.now().toIso8601String().split('T').first;
  downloadCsv(
    filename: 'TUGHE_Audit_Logs_$dateStamp.csv',
    headers: const [
      'ID',
      'Timestamp',
      'User',
      'Role',
      'Category',
      'Action',
      'Details',
      'Method',
      'Endpoint',
      'Status Code',
      'Duration (ms)',
      'IP Address',
    ],
    rows: logs
        .map((log) => [
              log.id,
              log.timestamp,
              log.userName,
              log.userRole,
              log.category,
              log.action,
              log.details,
              log.method,
              log.endpoint,
              log.statusCode,
              log.durationMs,
              log.ipAddress,
            ])
        .toList(),
  );
}
