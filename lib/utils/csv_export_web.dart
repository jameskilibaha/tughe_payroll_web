import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../models/audit_log_entry.dart';

/// Generic CSV download helper for the browser (used by both the Audit Log
/// export and the Reports page exports). Web-only (uses dart:html), which
/// matches this project's Flutter Web target.
void downloadCsv({
  required String filename,
  required List<String> headers,
  required List<List<Object?>> rows,
}) {
  String esc(Object? value) => '"${(value ?? '').toString().replaceAll('"', '""')}"';

  final buffer = StringBuffer()..writeln(headers.map(esc).join(','));
  for (final row in rows) {
    buffer.writeln(row.map(esc).join(','));
  }

  final bytes = utf8.encode(buffer.toString());
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();

  html.Url.revokeObjectUrl(url);
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
