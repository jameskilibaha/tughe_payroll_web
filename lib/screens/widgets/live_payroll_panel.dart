import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../../controllers/payroll_controller.dart';
import '../../core/theme.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';
import '../../utils/formatters.dart';

/// Live view of a payroll run: progress bar, counters, the employee being
/// processed right now and a log of every employee as soon as it is finished
/// (open a row to see its NSSF / PAYE / allowances / deductions lines).
class LivePayrollPanel extends StatelessWidget {
  const LivePayrollPanel({
    super.key,
    required this.controller,
    this.expandLog = false,
    this.bordered = true,
    this.onMinimize,
    this.onClose,
  });

  final PayrollController controller;

  /// In a pop-up the live log fills the remaining height; inline it has a fixed height.
  final bool expandLog;

  /// Draw the coloured outline (inline use); a dialog has its own frame.
  final bool bordered;

  /// Shown while running: hides the pop-up but keeps the run going.
  final VoidCallback? onMinimize;

  /// Called after "Funga" (finished runs) so a pop-up can close itself.
  final VoidCallback? onClose;

  static String _mmss(double seconds) {
    final s = seconds.isNaN || seconds < 0 ? 0 : seconds.round();
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  static String _monthLabel(String monthYear) {
    const months = [
      'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni',
      'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba',
    ];
    final parts = monthYear.split('-');
    final m = parts.length == 2 ? int.tryParse(parts[1]) : null;
    return (m == null || m < 1 || m > 12) ? monthYear : '${months[m - 1]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final c = controller;
      final status = c.liveStatus.value;
      if (status == 'idle') return const SizedBox.shrink();

      final running = c.liveRunning;
      final total = c.liveTotal.value;
      final done = c.liveProcessed.value + c.liveSkipped.value + c.liveProblems.value;
      final double? progress = total == 0 ? (running ? null : 1.0) : (done / total).clamp(0.0, 1.0);
      final elapsed = c.liveElapsed.value;
      final eta = (running && done > 0 && total > done) ? elapsed / done * (total - done) : null;

      final Color accent = switch (status) {
        'completed' => Colors.green.shade700,
        'cancelled' => Colors.orange.shade800,
        'failed' => Colors.red.shade700,
        _ => AppColors.primaryBlue,
      };
      final String title = switch (status) {
        'starting' => 'Inaanza payroll ya ${_monthLabel(c.liveMonth.value)}...',
        'running' => 'Payroll ya ${_monthLabel(c.liveMonth.value)} inaendeshwa moja kwa moja',
        'completed' => 'Payroll ya ${_monthLabel(c.liveMonth.value)} imekamilika',
        'cancelled' => 'Payroll ya ${_monthLabel(c.liveMonth.value)} imesitishwa',
        _ => 'Payroll ya ${_monthLabel(c.liveMonth.value)} imeshindwa',
      };

      final conn = c.liveConnection.value;
      final (String connText, Color connColor) = switch (conn) {
        'websocket' => ('Live (WebSocket)', Colors.green.shade700),
        'polling' => ('Polling (HTTP)', Colors.amber.shade800),
        'offline' => ('Hakuna mtandao', Colors.red.shade700),
        _ => ('Inaunganisha...', Pal.textMuted),
      };

      final entries = c.liveLog.reversed.take(200).toList();

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Pal.surface,
          borderRadius: BorderRadius.circular(14),
          border: bordered ? Border.all(color: accent.withOpacity(0.55), width: 1.4) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: expandLog ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Row(
              children: [
                if (running)
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: accent))
                else
                  Icon(
                    status == 'completed'
                        ? Icons.check_circle
                        : status == 'cancelled'
                            ? Icons.stop_circle_outlined
                            : Icons.error_outline,
                    color: accent,
                    size: 22,
                  ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Pal.fg(accent)))),
                if (running)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: connColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text('● $connText', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Pal.fg(connColor))),
                  ),
                Text(_mmss(elapsed), style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Pal.textSecondary)),
                const SizedBox(width: 10),
                if (running && onMinimize != null)
                  IconButton(
                    tooltip: tr('Punguza (payroll inaendelea)'),
                    visualDensity: VisualDensity.compact,
                    onPressed: onMinimize,
                    icon: const Icon(Icons.minimize, size: 18),
                  ),
                if (running)
                  OutlinedButton.icon(
                    onPressed: c.liveCancelRequested.value ? null : c.cancelLive,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700, side: BorderSide(color: Colors.red.shade700)),
                    icon: const Icon(Icons.stop, size: 16),
                    label: Text(c.liveCancelRequested.value ? 'Inasitisha...' : 'Sitisha', style: const TextStyle(fontSize: 11)),
                  )
                else
                  TextButton.icon(
                    onPressed: () {
                      c.dismissLive();
                      onClose?.call();
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Funga', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 10, color: accent, backgroundColor: Pal.surfaceAlt),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(total == 0 ? 'Inaandaa...' : '$done / $total wameshughulikiwa (${((progress ?? 0) * 100).toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Pal.textSecondary)),
                const Spacer(),
                if (eta != null) Text('Muda uliobaki takriban ${_mmss(eta)}', style: TextStyle(fontSize: 10.5, color: Pal.textMuted)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _chip('Waliofanikiwa: ${c.liveProcessed.value}', Colors.green),
              _chip('Waliorukwa (tayari): ${c.liveSkipped.value}', Colors.blueGrey),
              _chip('Wenye matatizo: ${c.liveProblems.value}', Colors.red),
            ]),
            if (running && c.liveCurrent.value.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.person_outline, size: 16, color: Pal.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Sasa hivi: ${c.liveCurrent.value} (${c.liveIndex.value}/$total)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Pal.text)),
                ),
              ]),
            ],
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Mtiririko wa moja kwa moja', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Pal.textMuted)),
              const SizedBox(height: 6),
              if (expandLog)
                Expanded(child: _logBox(entries, shrink: false))
              else
                _logBox(entries, shrink: true),
            ],
          ],
        ),
      );
    });
  }

  Widget _logBox(List<Map<String, dynamic>> entries, {required bool shrink}) {
    return Builder(builder: (context) {
      final list = ListView.separated(
        shrinkWrap: shrink,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: entries.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Pal.border),
        itemBuilder: (context, i) => _entry(context, entries[i]),
      );
      return Container(
        constraints: shrink ? const BoxConstraints(maxHeight: 300) : null,
        decoration: BoxDecoration(
          color: Pal.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Pal.border),
        ),
        child: list,
      );
    });
  }

  Widget _chip(String text, MaterialColor color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Pal.tint(color), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Pal.fg(color.shade700))),
      );

  Widget _entry(BuildContext context, Map<String, dynamic> e) {
    final type = e['type'] as String? ?? '';
    final name = (e['name'] as String?) ?? '';
    final index = (e['index'] as num?)?.toInt();
    final prefix = index == null ? '' : '$index. ';

    if (type == 'employee_done') {
      final lines = (e['lines'] as List? ?? const []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(40, 0, 12, 8),
          leading: Icon(Icons.check_circle, size: 18, color: Pal.fg(Colors.green.shade700)),
          subtitle: ((e['debtsCleared'] as List?) ?? const []).isEmpty
              ? null
              : Text('Deni limekwisha: ${((e['debtsCleared'] as List).join(', '))} - makato yameondolewa',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Pal.fg(Colors.teal.shade700))),
          title: Row(
            children: [
              Expanded(child: Text('$prefix$name', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Pal.text))),
              Text('Net ${formatTZS((e['net'] as num?) ?? 0)}',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Pal.fg(Colors.green.shade700))),
            ],
          ),
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(
                  children: [
                    Expanded(child: Text('${l['name']}', style: TextStyle(fontSize: 10.5, color: Pal.textSecondary))),
                    Text(formatTZS((l['amount'] as num?) ?? 0), style: TextStyle(fontSize: 10.5, color: Pal.text)),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    final isProblem = type == 'employee_problem';
    final detail = isProblem ? (e['detail'] as String? ?? '') : 'Tayari alikuwa amefanyiwa payroll ya mwezi huu';
    final color = isProblem ? Colors.red.shade700 : Colors.blueGrey.shade600;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isProblem ? Icons.error_outline : Icons.skip_next, size: 18, color: Pal.fg(color)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$prefix$name', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Pal.text)),
                Text(detail, style: TextStyle(fontSize: 10.5, color: Pal.fg(color))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the live payroll view as a pop-up. It cannot be dismissed by tapping
/// outside while the run is going (use "Punguza" to hide it - the run continues);
/// after the run, "Funga" closes it.
Future<void> showLivePayrollDialog(BuildContext context, PayrollController controller) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final size = MediaQuery.of(dialogContext).size;
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: math.min(1000, size.width - 32),
          height: math.min(740, size.height - 32),
          child: LivePayrollPanel(
            controller: controller,
            expandLog: true,
            bordered: false,
            onMinimize: () => Navigator.of(dialogContext).pop(),
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      );
    },
  );
}

/// A slim status bar shown on the page while the pop-up is hidden: progress at a
/// glance and a button to open the pop-up again.
class LivePayrollStrip extends StatelessWidget {
  const LivePayrollStrip({super.key, required this.controller, required this.onOpen});

  final PayrollController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final c = controller;
      final status = c.liveStatus.value;
      if (status == 'idle') return const SizedBox.shrink();
      final running = c.liveRunning;
      final total = c.liveTotal.value;
      final done = c.liveProcessed.value + c.liveSkipped.value + c.liveProblems.value;
      final double? progress = total == 0 ? (running ? null : 1.0) : (done / total).clamp(0.0, 1.0);
      final accent = switch (status) {
        'completed' => Colors.green.shade700,
        'cancelled' => Colors.orange.shade800,
        'failed' => Colors.red.shade700,
        _ => AppColors.primaryBlue,
      };
      final label = running
          ? 'Payroll inaendelea: $done / $total'
          : switch (status) {
              'completed' => 'Payroll imekamilika: ${c.liveProcessed.value} wamefanikiwa',
              'cancelled' => 'Payroll imesitishwa',
              _ => 'Payroll imeshindwa',
            };
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Pal.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.55), width: 1.2),
        ),
        child: Row(
          children: [
            if (running)
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.2, color: accent))
            else
              Icon(status == 'completed' ? Icons.check_circle : Icons.info_outline, color: accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Pal.fg(accent))),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: progress, minHeight: 6, color: accent, backgroundColor: Pal.surfaceAlt),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_full, size: 16),
              label: const Text('Fungua', style: TextStyle(fontSize: 11)),
            ),
            if (!running)
              IconButton(
                tooltip: tr('Funga'),
                visualDensity: VisualDensity.compact,
                onPressed: c.dismissLive,
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      );
    });
  }
}
