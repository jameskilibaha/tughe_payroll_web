import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/statutory_controller.dart';
import '../../core/theme.dart';
import '../../core/tr_snack.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';
import 'form_kit.dart';

/// The state of a payroll month: open (can be run, reversed, adjusted), submitted (waiting for approval) or
/// closed (locked). An Admin approves and closes; with "require approval" on, the person who submitted a
/// month cannot close it himself. Once a month is closed (or approval is not required) the payslips can be
/// e-mailed to the employees.
class PeriodStatusCard extends StatefulWidget {
  const PeriodStatusCard({super.key, required this.month});

  final String month; // YYYY-MM

  @override
  State<PeriodStatusCard> createState() => _PeriodStatusCardState();
}

class _PeriodStatusCardState extends State<PeriodStatusCard> {
  final _ctrl = Get.find<StatutoryController>();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl.loadPeriod(widget.month);
  }

  @override
  void didUpdateWidget(covariant PeriodStatusCard old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) _ctrl.loadPeriod(widget.month);
  }

  Future<String?> _askNote(String title, String hint, {required bool required}) async {
    final c = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 380,
            child: AppTextField(label: hint, controller: c, required: required, maxLines: 3, errorText: error, autofocus: true),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Ghairi')),
            ElevatedButton(
              onPressed: () {
                if (required && c.text.trim().length < 5) {
                  set(() => error = 'Andika sababu (angalau herufi 5).');
                  return;
                }
                Navigator.of(dialogContext).pop(c.text.trim());
              },
              child: const Text('Endelea'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Ghairi')),
            ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Ndiyo, Endelea')),
          ],
        ),
      ) ??
      false;

  Future<void> _act(String action, {String? note, String? done}) async {
    setState(() => _busy = true);
    final failure = await _ctrl.periodAction(widget.month, action, note: note);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      trSnack('Imeshindikana', failure);
    } else if (done != null) {
      trSnack('Imefanikiwa', done);
    }
  }

  Future<void> _email() async {
    final ok = await _confirm('Tuma Hati kwa Barua Pepe',
        'Hati za mshahara za ${widget.month} zitatumwa kwa barua pepe ya kila mfanyakazi aliye na payroll ya mwezi huo. Endelea?');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final r = await _ctrl.sendPayslips(widget.month);
      if (!mounted) return;
      final summary = Map<String, dynamic>.from(r['summary'] as Map);
      final failed = (r['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).where((e) => e['ok'] != true).toList();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Matokeo ya Kutuma'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Zimetumwa: ${summary['sent']} kati ya ${summary['total']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (failed.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Hazikutumwa (${failed.length}):', style: TextStyle(color: Pal.danger, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [for (final f in failed) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('${f['name']}: ${f['detail']}', style: const TextStyle(fontSize: 11.5)))]),
                  ),
                ),
              ],
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Sawa'))],
        ),
      );
    } catch (e) {
      trSnack('Imeshindikana', e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = _ctrl.period.value;
      if (p == null) {
        return _ctrl.loadingPeriod.value ? const LinearProgressIndicator(minHeight: 3) : const SizedBox.shrink();
      }
      final status = p['status'] as String;
      final payslips = (p['payslips'] as num?)?.toInt() ?? 0;
      final require = p['requireApproval'] == true;
      final isAdmin = Get.find<AuthController>().isAdmin;
      final color = status == 'CLOSED' ? Colors.green : (status == 'SUBMITTED' ? Colors.orange : Colors.blue);
      final label = switch (status) {
        'CLOSED' => 'Umefungwa',
        'SUBMITTED' => 'Umewasilishwa kwa idhini',
        _ => 'Uko wazi',
      };
      final detail = switch (status) {
        'CLOSED' => 'Umefungwa na ${p['closedBy'] ?? '-'}. Hakuna kuendesha, kubatilisha wala kurekebisha hadi Admin auifungue tena.',
        'SUBMITTED' => 'Umewasilishwa na ${p['preparedBy'] ?? '-'}. Hakuna kubadilisha hadi uidhinishwe au urudishwe.',
        _ => payslips == 0 ? 'Payroll ya mwezi huu haijaendeshwa bado.' : 'Payroll imeendeshwa kwa wafanyakazi $payslips. Ukiridhika, uwasilishe kwa idhini.',
      };
      final log = (p['log'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).take(3).toList();
      final canEmail = payslips > 0 && _ctrl.emailReady.value && (status == 'CLOSED' || !require);

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.fg(color.shade700).withOpacity(0.5), width: 1.4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(status == 'CLOSED' ? Icons.lock : (status == 'SUBMITTED' ? Icons.hourglass_top : Icons.lock_open), size: 18, color: Pal.fg(color.shade700)),
              const SizedBox(width: 8),
              Text('Hali ya Mwezi ${widget.month}: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: Pal.tint(color), borderRadius: BorderRadius.circular(8)),
                child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Pal.fg(color.shade700))),
              ),
              if (require) ...[
                const SizedBox(width: 8),
                Text('(idhini ya wawili)', style: TextStyle(fontSize: 10.5, color: Pal.textMuted)),
              ],
            ]),
            const SizedBox(height: 6),
            Text(detail, style: TextStyle(fontSize: 11.5, height: 1.35, color: Pal.textSecondary)),
            if (log.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                [for (final l in log) '${_actionLabel(l['action'] as String)}: ${l['by']}${(l['note'] as String? ?? '').isEmpty ? '' : ' - ${l['note']}'}'].join('   |   '),
                style: TextStyle(fontSize: 10.5, color: Pal.textMuted),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 8, children: [
              if (status == 'OPEN' && payslips > 0)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _act('submit', done: 'Mwezi umewasilishwa kwa idhini.'),
                  icon: const Icon(Icons.send_outlined, size: 17),
                  label: const Text('Wasilisha kwa Idhini'),
                ),
              if (status == 'SUBMITTED')
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final note = await _askNote('Rudisha kwa Marekebisho', 'Kwa nini unarudisha? (hiari)', required: false);
                          if (note != null) _act('return', note: note, done: 'Mwezi umerudishwa; unaweza kurekebisha.');
                        },
                  icon: const Icon(Icons.undo, size: 17),
                  label: const Text('Rudisha kwa Marekebisho'),
                ),
              if (isAdmin && ((status == 'SUBMITTED') || (status == 'OPEN' && !require && payslips > 0)))
                ElevatedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (await _confirm('Funga Mwezi ${widget.month}', 'Mwezi ukifungwa hakuna kuendesha, kubatilisha wala kurekebisha payroll yake. Funga?')) {
                            _act('close', done: 'Mwezi umefungwa.');
                          }
                        },
                  icon: const Icon(Icons.verified_outlined, size: 17),
                  label: Text(status == 'SUBMITTED' ? 'Idhinisha na Funga' : 'Funga Mwezi'),
                ),
              if (isAdmin && status == 'CLOSED')
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final reason = await _askNote('Fungua Mwezi Tena', 'Sababu ya kufungua', required: true);
                          if (reason != null) _act('reopen', note: reason, done: 'Mwezi umefunguliwa tena.');
                        },
                  icon: const Icon(Icons.lock_open, size: 17),
                  label: const Text('Fungua Tena'),
                ),
              if (canEmail)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _email,
                  icon: const Icon(Icons.mail_outline, size: 17),
                  label: const Text('Tuma Hati kwa Barua Pepe'),
                ),
            ]),
          ],
        ),
      );
    });
  }

  String _actionLabel(String a) => switch (a) {
        'SUBMIT' => tr('Imewasilishwa'),
        'RETURN' => tr('Imerudishwa'),
        'CLOSE' => tr('Imefungwa'),
        'REOPEN' => tr('Imefunguliwa'),
        _ => a,
      };
}
