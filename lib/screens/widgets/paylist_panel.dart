import 'package:flutter/material.dart' hide Text;

import '../../core/theme.dart';
import '../../core/tr_text.dart';
import '../../models/employee.dart';
import '../../models/payroll_calculation_result.dart';
import '../../utils/formatters.dart';
import 'data_grid.dart';

typedef PaylistRow = ({Employee employee, PayrollCalculationResult calc});

/// One column the bank paylist can have.
class PaylistColumn {
  const PaylistColumn(this.key, this.label, this.value, {this.numeric = false, this.defaultOn = false, this.locked = false});

  final String key;
  final String label;
  final Object? Function(PaylistRow r, String monthLabel) value;
  final bool numeric;
  final bool defaultOn;

  /// A paylist cannot go without it (who gets paid, and how much).
  final bool locked;
}

String _bank(PaylistRow r) => (r.employee.salaryStatus?.bankName ?? '').trim();
String _account(PaylistRow r) => (r.employee.salaryStatus?.bankAccountNumber ?? '').trim();

/// Every column a bank / the accountant may ask for, in the order they are printed.
final List<PaylistColumn> paylistCatalog = [
  PaylistColumn('sn', 'SN', (r, m) => 0, defaultOn: true),
  PaylistColumn('pf', 'PF ID', (r, m) => r.employee.id, defaultOn: true),
  PaylistColumn('empNo', 'Namba ya Mfanyakazi', (r, m) => r.employee.employeeIdNumber),
  PaylistColumn('name', 'Jina Kamili', (r, m) => r.calc.employeeName, defaultOn: true, locked: true),
  PaylistColumn('bank', 'Jina la Benki', (r, m) => _bank(r), defaultOn: true),
  PaylistColumn('account', 'Namba ya Akaunti', (r, m) => _account(r), defaultOn: true),
  PaylistColumn('net', 'Kiasi cha Kutuma (Net Pay)', (r, m) => r.calc.netSalary, numeric: true, defaultOn: true, locked: true),
  PaylistColumn('narration', 'Maelezo (Narration)', (r, m) => 'MSHAHARA ${m.toUpperCase()}', defaultOn: true),
  PaylistColumn('phone', 'Simu', (r, m) => r.employee.mobileNumber),
  PaylistColumn('email', 'Barua Pepe', (r, m) => r.employee.email),
  PaylistColumn('station', 'Kituo cha Kazi', (r, m) => r.employee.salaryStatus?.workStation ?? ''),
  PaylistColumn('occupation', 'Cheo', (r, m) => r.employee.salaryStatus?.occupation ?? ''),
  PaylistColumn('basic', 'Mshahara wa Msingi', (r, m) => r.calc.basicSalary, numeric: true),
  PaylistColumn('gross', 'Mshahara Ghafi', (r, m) => r.calc.grossSalary, numeric: true),
  PaylistColumn('deductions', 'Jumla ya Makato', (r, m) => r.calc.totalDeductions, numeric: true),
];

Set<String> defaultPaylistKeys() => {for (final c in paylistCatalog) if (c.defaultOn) c.key};

/// Keys that exist and always include the locked ones.
Set<String> normalizePaylistKeys(Iterable<Object?>? keys) {
  final wanted = {for (final k in keys ?? const <Object?>[]) '$k'};
  final out = {for (final c in paylistCatalog) if (c.locked || wanted.contains(c.key)) c.key};
  return wanted.isEmpty ? defaultPaylistKeys() : out;
}

/// (headers, rows, totals) for the chosen columns - one source for the screen, the CSV and the PDF.
({List<String> headers, List<List<Object?>> rows, List<Object?> totals, Set<int> numeric}) buildPaylist(
    List<PaylistRow> rows, Set<String> keys, String monthLabel) {
  final cols = [for (final c in paylistCatalog) if (keys.contains(c.key)) c];
  final data = <List<Object?>>[
    for (var i = 0; i < rows.length; i++) [for (final c in cols) c.key == 'sn' ? i + 1 : c.value(rows[i], monthLabel)],
  ];
  var labelPlaced = false;
  final totals = <Object?>[
    for (var i = 0; i < cols.length; i++)
      if (cols[i].numeric)
        data.fold<double>(0, (s, r) => s + ((r[i] as num?)?.toDouble() ?? 0))
      else if (!labelPlaced && cols[i].key != 'sn' && cols[i].key != 'pf')
        () {
          labelPlaced = true;
          return 'JUMLA';
        }()
      else
        '',
  ];
  return (
    headers: [for (final c in cols) c.label],
    rows: data,
    totals: totals,
    numeric: {for (var i = 0; i < cols.length; i++) if (cols[i].numeric) i},
  );
}

/// The bank paylist: choose the columns the bank needs, see the total per bank and the employees who
/// cannot be paid yet (no bank / account number, or nothing to pay), then CSV / PDF from the report header.
class PaylistPanel extends StatelessWidget {
  const PaylistPanel({super.key, required this.rows, required this.monthLabel, required this.keys, required this.onKeysChanged});

  final List<PaylistRow> rows;
  final String monthLabel;
  final Set<String> keys;
  final ValueChanged<Set<String>> onKeysChanged;

  Future<void> _chooseColumns(BuildContext context) async {
    final chosen = Set<String>.from(keys);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Safu za Paylist'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: () => setLocal(() => chosen..clear()..addAll(defaultPaylistKeys())), child: const Text('Rudisha za kawaida')),
                ),
                for (final c in paylistCatalog)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: c.locked || chosen.contains(c.key),
                    title: Text(c.label, style: const TextStyle(fontSize: 13)),
                    subtitle: c.locked ? const Text('Inahitajika kila wakati', style: TextStyle(fontSize: 10.5)) : null,
                    onChanged: c.locked ? null : (v) => setLocal(() => v == true ? chosen.add(c.key) : chosen.remove(c.key)),
                  ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ghairi')),
            FilledButton(onPressed: () => Navigator.pop(ctx, chosen), child: const Text('Tumia')),
          ],
        ),
      ),
    );
    if (result != null) onKeysChanged(normalizePaylistKeys(result));
  }

  @override
  Widget build(BuildContext context) {
    final byBank = <String, ({int count, double total})>{};
    final problems = <String>[];
    for (final r in rows) {
      final b = _bank(r).isEmpty ? '(Hana benki)' : _bank(r);
      final cur = byBank[b] ?? (count: 0, total: 0.0);
      byBank[b] = (count: cur.count + 1, total: cur.total + r.calc.netSalary);
      final why = [
        if (_bank(r).isEmpty) 'hana benki',
        if (_account(r).isEmpty) 'hana namba ya akaunti',
        if (r.calc.netSalary <= 0) 'hana kiasi cha kulipwa',
      ];
      if (why.isNotEmpty) problems.add('${r.calc.employeeName} (${why.join(', ')})');
    }
    final banks = byBank.keys.toList()..sort((a, b) => byBank[b]!.total.compareTo(byBank[a]!.total));
    final p = buildPaylist(rows, keys, monthLabel);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Pal.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text('Paylist ya $monthLabel - safu ${p.headers.length}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Pal.brandText)),
          ),
          OutlinedButton.icon(
            onPressed: () => _chooseColumns(context),
            icon: const Icon(Icons.view_column_outlined, size: 18),
            label: const Text('Chagua Safu'),
          ),
        ]),
        const SizedBox(height: 10),
        if (problems.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Pal.tint(Colors.orange), borderRadius: BorderRadius.circular(10)),
            child: Text(
              'Wafanyakazi ${problems.length} hawawezi kulipwa benki bado: ${problems.take(5).join('; ')}${problems.length > 5 ? '; na ${problems.length - 5} wengine...' : ''}. Rekebisha kwenye Wafanyakazi > Hali ya Mshahara.',
              style: TextStyle(fontSize: 11, color: Pal.fg(Colors.orange.shade900), fontWeight: FontWeight.w600),
            ),
          ),
        if (banks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final b in banks)
                Chip(
                  label: Text('$b: ${byBank[b]!.count} - ${formatTZS(byBank[b]!.total).replaceFirst('TZS ', '')}', style: const TextStyle(fontSize: 11)),
                  backgroundColor: Pal.surfaceAlt,
                  side: BorderSide(color: Pal.border),
                ),
            ]),
          ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('Hakuna Rekodi Zinazolingana.', style: TextStyle(color: Pal.textMuted))),
          )
        else
          AppDataGrid(
            key: ValueKey('${keys.join(',')}|$monthLabel|${rows.length}'),
            headers: p.headers,
            rows: p.rows,
            totals: p.totals,
            numeric: p.numeric,
            pageSize: 50,
          ),
      ]),
    );
  }
}
