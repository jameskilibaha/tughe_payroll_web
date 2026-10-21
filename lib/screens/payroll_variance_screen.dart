import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../controllers/statutory_controller.dart';
import '../core/theme.dart';
import '../core/tr_text.dart';
import '../core/translations.dart';
import '../utils/csv_export_web.dart';
import '../utils/formatters.dart';
import 'widgets/app_status_views.dart';
import 'widgets/form_kit.dart';

/// "Tofauti ya Mwezi": who is paid differently this month than last month, and WHY. Read it before
/// approving a payroll - a mistake (a wrong salary, an allowance left out, a deduction twice) shows up here.
class PayrollVarianceScreen extends StatefulWidget {
  const PayrollVarianceScreen({super.key});

  @override
  State<PayrollVarianceScreen> createState() => _PayrollVarianceScreenState();
}

class _PayrollVarianceScreenState extends State<PayrollVarianceScreen> {
  final _ctrl = Get.find<StatutoryController>();
  final _search = TextEditingController();
  late String _month;
  String _filter = 'ALL'; // ALL | NEW | LEFT | CHANGED | SAME

  late final List<String> _months = () {
    final now = DateTime.now();
    return [for (var i = 0; i < 18; i++) _fmt(DateTime(now.year, now.month - i, 1))];
  }();

  static String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = _fmt(DateTime(now.year, now.month - (now.day < 20 ? 1 : 0), 1));
    _ctrl.loadVariance(_month);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const _labels = {'NEW': 'Mpya', 'LEFT': 'Ameondoka', 'CHANGED': 'Amebadilika', 'SAME': 'Hakuna mabadiliko'};

  MaterialColor _color(String s) => switch (s) {
        'NEW' => Colors.green,
        'LEFT' => Colors.red,
        'CHANGED' => Colors.orange,
        _ => Colors.blueGrey,
      };

  void _export(Map<String, dynamic> v) {
    final rows = (v['rows'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    downloadCsv(
      filename: 'TUGHE_Tofauti_${v['monthYear']}.csv',
      headers: ['Namba', 'Jina', 'Hali', 'Net ${v['previousMonth']}', 'Net ${v['monthYear']}', 'Tofauti', 'Tofauti %', 'Sababu'],
      rows: [
        for (final r in rows)
          [r['employeeNumber'], r['name'], _labels[r['status']] ?? r['status'], (r['previousNet'] as num).toDouble(), (r['net'] as num).toDouble(),
            (r['netChange'] as num).toDouble(), r['netChangePct'] ?? '', (r['reasons'] as List).join(' ; ')]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final v = _ctrl.variance.value;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('TOFAUTI YA MWEZI (VARIANCE)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Pal.brandText)),
            const SizedBox(height: 4),
            Text('Inalinganisha payroll ya mwezi huu na wa mwezi uliopita: nani amebadilika na kwa nini (mshahara, posho au kato lililoongezwa, kuondolewa au kubadilika). Isome kabla ya kuidhinisha payroll.',
                style: TextStyle(fontSize: 11.5, height: 1.35, color: Pal.textSecondary)),
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 180,
                child: AppDropdown<String>(
                  label: 'Mwezi',
                  value: _month,
                  items: _months,
                  onChanged: (m) {
                    if (m == null) return;
                    setState(() => _month = m);
                    _ctrl.loadVariance(m);
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search, size: 18), hintText: tr('Tafuta jina au namba...')),
                ),
              ),
              OutlinedButton.icon(
                onPressed: v == null || (v['rows'] as List).isEmpty ? null : () => _export(v),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Pakua CSV'),
              ),
            ]),
            const SizedBox(height: 14),
            if (_ctrl.loadingVariance.value && v == null)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: AppLoadingIndicator(message: 'Inalinganisha miezi...'))
            else if (v == null)
              AppErrorRetryView(message: _ctrl.varianceError.value ?? 'Imeshindwa kupakua.', onRetry: () => _ctrl.loadVariance(_month))
            else if ((v['rows'] as List).isEmpty)
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.border)),
                child: Text('Hakuna payroll ya mwezi $_month wala wa mwezi uliopita.', textAlign: TextAlign.center, style: TextStyle(color: Pal.textSecondary)),
              )
            else
              ..._content(v),
            const SizedBox(height: 24),
          ],
        ),
      );
    });
  }

  List<Widget> _content(Map<String, dynamic> v) {
    final summary = Map<String, dynamic>.from(v['summary'] as Map);
    final totals = Map<String, dynamic>.from(v['totals'] as Map);
    final q = _search.text.trim().toLowerCase();
    final rows = (v['rows'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((r) => (_filter == 'ALL' || r['status'] == _filter) && (q.isEmpty || '${r['name']} ${r['employeeNumber']}'.toLowerCase().contains(q)))
        .toList();
    final change = (totals['change'] as num).toDouble();
    return [
      if (v['hasPrevious'] != true)
        FormNotice('Hakuna payroll ya mwezi uliopita (${v['previousMonth']}) wa kulinganisha nao.', kind: NoticeKind.info),
      Wrap(spacing: 10, runSpacing: 8, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Pal.tint(Colors.blue), borderRadius: BorderRadius.circular(12), border: Border.all(color: Pal.primary, width: 1.4)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Net ya wote ${v['monthYear']}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Pal.textSecondary)),
            const SizedBox(height: 4),
            Text(formatTZS((totals['net'] as num).toDouble()), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            Text('${change >= 0 ? '+' : ''}${formatTZS(change)} dhidi ya ${v['previousMonth']}',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: change >= 0 ? Colors.green.shade700 : Colors.red.shade700)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        ChoiceChip(label: Text('Wote (${(v['rows'] as List).length})', style: const TextStyle(fontSize: 11.5)), selected: _filter == 'ALL', onSelected: (_) => setState(() => _filter = 'ALL')),
        for (final k in const ['NEW', 'LEFT', 'CHANGED', 'SAME'])
          ChoiceChip(
            label: Text('${tr(_labels[k]!)} (${summary[k]})', style: const TextStyle(fontSize: 11.5)),
            selected: _filter == k,
            onSelected: (_) => setState(() => _filter = k),
          ),
      ]),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.border)),
        clipBehavior: Clip.antiAlias,
        child: rows.isEmpty
            ? Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Hakuna anayelingana.', style: TextStyle(color: Pal.textMuted))))
            : Column(children: [
                for (var i = 0; i < rows.length; i++) ...[
                  _row(rows[i]),
                  if (i != rows.length - 1) Divider(height: 1, color: Pal.border),
                ],
              ]),
      ),
    ];
  }

  Widget _row(Map<String, dynamic> r) {
    final status = r['status'] as String;
    final color = _color(status);
    final change = (r['netChange'] as num).toDouble();
    final pct = r['netChangePct'] as num?;
    final reasons = (r['reasons'] as List).map((e) => '$e').toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Pal.tint(color), borderRadius: BorderRadius.circular(7)),
            child: Text(_labels[status] ?? status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Pal.fg(color.shade700))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r['name']}  (${r['employeeNumber']})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                for (final reason in reasons) Padding(padding: const EdgeInsets.only(top: 3), child: Text('• $reason', style: TextStyle(fontSize: 11, color: Pal.textSecondary))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatTZS((r['net'] as num).toDouble()), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              Text(
                '${change >= 0 ? '+' : ''}${formatTZS(change)}${pct == null ? '' : '  (${pct >= 0 ? '+' : ''}$pct%)'}',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: change == 0 ? Pal.textMuted : (change > 0 ? Colors.green.shade700 : Colors.red.shade700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
