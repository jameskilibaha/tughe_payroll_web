import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../../controllers/employee_controller.dart';
import '../../controllers/statutory_controller.dart';
import '../../core/theme.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';
import '../../network/api_exception.dart';
import '../../utils/csv_export_web.dart';
import 'form_kit.dart';

/// Bulk import of employees from an Excel (.xlsx) or CSV file: pick the file, READ THE PREVIEW (what will be
/// created, what will be updated, which rows have errors - nothing is saved yet), then confirm.
class ImportEmployeesDialog extends StatefulWidget {
  const ImportEmployeesDialog({super.key});

  @override
  State<ImportEmployeesDialog> createState() => _ImportEmployeesDialogState();
}

class _ImportEmployeesDialogState extends State<ImportEmployeesDialog> {
  final _ctrl = Get.find<StatutoryController>();

  String? _filename;
  String? _base64;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _result;
  bool _busy = false;
  String? _error;

  Future<void> _template() async {
    try {
      final t = await _ctrl.importTemplate();
      final headers = List<String>.from(t['headers'] as List);
      final sample = (t['sample'] as List).map((r) => List<Object?>.from(r as List)).toList();
      downloadCsv(filename: 'TUGHE_kiolezo_cha_wafanyakazi.csv', headers: headers, rows: sample);
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : e.toString());
    }
  }

  Future<void> _pick() async {
    final input = html.FileUploadInputElement()..accept = '.csv,.xlsx';
    input.click();
    await input.onChange.first;
    final file = input.files?.first;
    if (file == null) return;
    final reader = html.FileReader()..readAsArrayBuffer(file);
    await reader.onLoadEnd.first;
    final data = reader.result;
    final bytes = data is Uint8List ? data : Uint8List.view(data as ByteBuffer);
    if (bytes.length > 6 * 1024 * 1024) {
      setState(() => _error = 'Faili ni kubwa mno (zaidi ya MB 6).');
      return;
    }
    setState(() {
      _filename = file.name;
      _base64 = base64Encode(bytes);
      _preview = null;
      _result = null;
      _error = null;
      _busy = true;
    });
    try {
      final p = await _ctrl.importPreview(_filename!, _base64!);
      if (mounted) setState(() => _preview = p);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await _ctrl.importApply(_filename!, _base64!);
      if (Get.isRegistered<EmployeeController>()) Get.find<EmployeeController>().refreshFromBackend();
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _chip(String label, int n, MaterialColor color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Pal.tint(color), borderRadius: BorderRadius.circular(8)),
        child: Text('$label: $n', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Pal.fg(color.shade700))),
      );

  @override
  Widget build(BuildContext context) {
    final summary = _preview == null ? null : Map<String, dynamic>.from(_preview!['summary'] as Map);
    final rows = _preview == null ? const <Map<String, dynamic>>[] : (_preview!['rows'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final importable = summary == null ? 0 : ((summary['create'] as num) + (summary['update'] as num)).toInt();
    final done = _result != null;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760, maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
              child: Row(children: [
                Icon(Icons.upload_file, color: Pal.primary),
                const SizedBox(width: 10),
                const Expanded(child: Text('Ingiza Wafanyakazi kutoka Excel / CSV', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                IconButton(onPressed: _busy ? null : () => Navigator.of(context).pop(done), icon: const Icon(Icons.close)),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) FormNotice(_error!),
                    if (_filename == null && !done) ...[
                      const FormNotice(
                        'Faili liwe na mstari mmoja kwa kila mfanyakazi na vichwa vya safu juu. Pakua kiolezo ili kupata safu zote. Mfanyakazi mpya anatengenezewa akaunti ya kuingia (nenosiri la awali ni jina lake la mwisho kwa HERUFI KUBWA). Mfanyakazi aliyepo (namba sawa) anabadilishwa mshahara na taarifa za kisheria tu.',
                        kind: NoticeKind.info,
                      ),
                    ],
                    Wrap(spacing: 10, runSpacing: 8, children: [
                      OutlinedButton.icon(onPressed: _busy ? null : _template, icon: const Icon(Icons.download_outlined, size: 17), label: const Text('Pakua Kiolezo')),
                      ElevatedButton.icon(onPressed: (_busy || done) ? null : _pick, icon: const Icon(Icons.folder_open, size: 17), label: Text(_filename == null ? 'Chagua Faili' : 'Chagua Faili Lingine')),
                      if (_filename != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_filename!, style: TextStyle(fontSize: 12, color: Pal.textSecondary))),
                    ]),
                    if (_busy) const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: LinearProgressIndicator()),
                    if (summary != null && !done) ...[
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        _chip('Wapya', (summary['create'] as num).toInt(), Colors.green),
                        _chip('Kusasisha', (summary['update'] as num).toInt(), Colors.blue),
                        _chip('Wenye makosa', (summary['error'] as num).toInt(), Colors.red),
                        _chip('Jumla ya mistari', (summary['total'] as num).toInt(), Colors.blueGrey),
                      ]),
                      if ((_preview!['unknownColumns'] as List).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Safu zisizoeleweka (zimepuuzwa): ${(_preview!['unknownColumns'] as List).join(', ')}', style: TextStyle(fontSize: 11, color: Pal.textMuted)),
                        ),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 320),
                        decoration: BoxDecoration(border: Border.all(color: Pal.border), borderRadius: BorderRadius.circular(10)),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Pal.border),
                          itemBuilder: (_, i) {
                            final r = rows[i];
                            final action = r['action'] as String;
                            final color = action == 'create' ? Colors.green : (action == 'update' ? Colors.blue : Colors.red);
                            final messages = [...(r['errors'] as List), ...(r['warnings'] as List)].map((e) => '$e').toList();
                            return ListTile(
                              dense: true,
                              leading: Icon(action == 'create' ? Icons.person_add_alt_1 : (action == 'update' ? Icons.edit_outlined : Icons.error_outline), size: 20, color: Pal.fg(color.shade700)),
                              title: Text('${r['line']}.  ${r['employeeNumber']}  ${r['name']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              subtitle: messages.isEmpty
                                  ? null
                                  : Text(messages.join('\n'), style: TextStyle(fontSize: 10.5, color: action == 'error' ? Pal.danger : Pal.textMuted)),
                            );
                          },
                        ),
                      ),
                    ],
                    if (done) ...[
                      const SizedBox(height: 14),
                      FormNotice(
                        'Imekamilika: ${(_result!['summary'] as Map)['ok']} kati ya ${(_result!['summary'] as Map)['total']} zimefanikiwa.',
                        kind: ((_result!['summary'] as Map)['failed'] as num) == 0 ? NoticeKind.success : NoticeKind.info,
                      ),
                      for (final r in (_result!['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).where((r) => r['ok'] != true))
                        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Mstari ${r['line']} (${r['employeeNumber']}): ${r['detail']}', style: TextStyle(fontSize: 11.5, color: Pal.danger))),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            FormActions(
              cancelLabel: done ? 'Funga' : 'Ghairi',
              onCancel: () => Navigator.of(context).pop(done),
              onSubmit: (done || importable == 0 || _busy) ? null : _apply,
              busy: _busy && _preview != null && !done,
              submitLabel: importable == 0 ? 'Ingiza' : 'Ingiza ($importable)',
            ),
          ],
        ),
      ),
    );
  }
}
