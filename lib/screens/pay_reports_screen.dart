import 'package:flutter/material.dart' hide Text;

import '../core/theme.dart';
import '../core/tr_text.dart';
import '../core/translations.dart';
import '../network/api_exception.dart';
import '../network/api_service.dart';
import '../utils/csv_export_web.dart';
import '../utils/formatters.dart';
import '../utils/report_pdf.dart';
import 'widgets/app_status_views.dart';
import 'widgets/data_grid.dart';
import 'widgets/form_kit.dart';

/// "Ripoti za Makato na Posho": what was really deducted (arrears, with the balance of every debt) and
/// what was really paid as allowances, for one month or a range of months, plus the register of debts.
/// All figures come from the payroll that was run (`/api/pay-reports/...`); nothing is calculated here.
class PayReportsScreen extends StatefulWidget {
  const PayReportsScreen({super.key});

  @override
  State<PayReportsScreen> createState() => _PayReportsScreenState();
}

class _PayReportsScreenState extends State<PayReportsScreen> {
  final _api = ApiService();
  final _search = TextEditingController();

  static const _tabs = ['Makato (Arrears)', 'Posho (Allowances)', 'Madeni (Debts)'];
  int _tab = 0;
  late String _month;
  late String _to;
  final Set<String> _picked = {}; // chosen deductions / allowances / debts (empty = all)
  bool _hideStatutory = true; // NSSF / PAYE are in their own reports; show the deductions assigned to people
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  late final List<String> _months = () {
    final now = DateTime.now();
    return [for (var i = 0; i < 24; i++) _fmt(DateTime(now.year, now.month - i, 1))];
  }();

  static String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = _fmt(DateTime(now.year, now.month - (now.day < 20 ? 1 : 0), 1));
    _to = _month;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  double _n(Object? v) => (v as num?)?.toDouble() ?? 0;

  Future<void> _load() async {
    final tab = _tab;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = tab == 0
          ? await _api.arrearsReport(_month, _to)
          : tab == 1
              ? await _api.allowancesReport(_month, _to)
              : await _api.debtsReport();
      if (!mounted || tab != _tab) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || tab != _tab) return;
      setState(() {
        _data = null;
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  String get _period => _tab == 2
      ? 'Hadi sasa'
      : (_month == _to ? _month : '$_month - $_to');

  String get _nameKey => const ['deduction', 'allowance', 'debt'][_tab];

  List<Map<String, dynamic>> get _allRows =>
      ((_data?['rows'] as List?) ?? const []).map((r) => Map<String, dynamic>.from(r as Map)).toList();

  /// Every deduction / allowance / debt name present in the data - what the person can choose from.
  List<String> get _nameOptions {
    final names = <String>{
      for (final r in _allRows)
        if (!(_tab == 0 && _hideStatutory && r['statutory'] == true)) '${r[_nameKey]}'
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  List<Map<String, dynamic>> get _rows {
    final all = _allRows;
    final q = _search.text.trim().toLowerCase();
    return all.where((r) {
      if (_tab == 0 && _hideStatutory && r['statutory'] == true) return false;
      if (_picked.isNotEmpty && !_picked.contains('${r[_nameKey]}')) return false;
      if (q.isEmpty) return true;
      return '${r['name']} ${r['employeeNumber']} ${r['deduction'] ?? r['allowance'] ?? r['debt']}'.toLowerCase().contains(q);
    }).toList();
  }

  /// headers / rows (numbers stay numbers) / totals of the open tab, for the table, the CSV and the PDF.
  ({String title, List<String> headers, List<List<Object?>> rows, List<Object?> totals, Set<int> numeric}) _table() {
    final rows = _rows;
    double sum(String k) => rows.fold(0.0, (a, r) => a + _n(r[k]));
    String months(Map<String, dynamic> r) => '${r['months']}';
    switch (_tab) {
      case 0:
        return (
          title: 'Ripoti ya Makato (Arrears)',
          headers: ['No', 'Namba', 'Jina', 'Kato', 'Miezi', 'Kiasi Kilichokatwa', 'Deni Lote', 'Limelipwa', 'Linalobaki', 'Hali'],
          rows: [
            for (var i = 0; i < rows.length; i++)
              [
                i + 1, rows[i]['employeeNumber'], rows[i]['name'], rows[i]['deduction'], months(rows[i]), _n(rows[i]['amount']),
                rows[i]['isDebt'] == true ? _n(rows[i]['debtTotal']) : null,
                rows[i]['isDebt'] == true ? _n(rows[i]['debtPaid']) : null,
                rows[i]['isDebt'] == true ? _n(rows[i]['debtRemaining']) : null,
                rows[i]['isDebt'] == true ? (rows[i]['debtStatus'] == 'PAID' ? 'Limelipwa lote' : 'Linaendelea') : '',
              ]
          ],
          totals: ['', 'JUMLA', '', '', '', sum('amount'), null, null, null, ''],
          numeric: {5, 6, 7, 8},
        );
      case 1:
        return (
          title: 'Ripoti ya Posho (Allowances)',
          headers: ['No', 'Namba', 'Jina', 'Posho', 'Miezi', 'Kiasi', 'Kodi'],
          rows: [
            for (var i = 0; i < rows.length; i++)
              [i + 1, rows[i]['employeeNumber'], rows[i]['name'], rows[i]['allowance'], months(rows[i]), _n(rows[i]['amount']),
                rows[i]['taxable'] == true ? 'Inatozwa kodi' : 'Haitozwi kodi']
          ],
          totals: ['', 'JUMLA', '', '', '', sum('amount'), ''],
          numeric: {5},
        );
      default:
        return (
          title: 'Rejista ya Madeni',
          headers: ['No', 'Namba', 'Jina', 'Deni', 'Jumla ya Deni', 'Kiasi cha Mwezi', 'Limelipwa', 'Linalobaki', 'Hali', 'Lilimalizika'],
          rows: [
            for (var i = 0; i < rows.length; i++)
              [i + 1, rows[i]['employeeNumber'], rows[i]['name'], rows[i]['debt'], _n(rows[i]['total']), _n(rows[i]['installment']),
                _n(rows[i]['paid']), _n(rows[i]['remaining']), rows[i]['status'] == 'PAID' ? 'Limelipwa lote' : 'Linaendelea', rows[i]['finishedMonth'] ?? '']
          ],
          totals: ['', 'JUMLA', '', '', sum('total'), null, sum('paid'), sum('remaining'), '', ''],
          numeric: {4, 5, 6, 7},
        );
    }
  }

  String get _fileStem => ['Makato', 'Posho', 'Madeni'][_tab];

  void _csv() {
    final t = _table();
    final pick = _picked.isEmpty ? '' : '_${(_picked.toList()..sort()).join('_').replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '')}';
    downloadCsv(filename: 'TUGHE_$_fileStem${pick}_${_tab == 2 ? 'sasa' : _period.replaceAll(' ', '')}.csv', headers: t.headers, rows: [...t.rows, t.totals]);
  }

  Future<void> _pdf() async {
    final t = _table();
    final note = [
      if (_picked.isNotEmpty) '${['Kato', 'Posho', 'Deni'][_tab]}: ${(_picked.toList()..sort()).join(', ')}',
      if (_tab == 0 && _hideStatutory) 'Makato ya kisheria (NSSF, PAYE) hayamo - yapo kwenye Ripoti za Kisheria.',
    ].join('  |  ');
    await printReportPdf(
      title: t.title,
      periodLabel: _period,
      headers: t.headers,
      rows: t.rows,
      totals: t.rows.isEmpty ? null : t.totals,
      filterNote: note.isEmpty ? null : note,
    );
  }

  Future<void> _pickNames() async {
    final options = _nameOptions;
    final chosen = Set<String>.from(_picked);
    final label = ['kato', 'posho', 'deni'][_tab];
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Chagua $label'),
          content: SizedBox(
            width: 380,
            child: options.isEmpty
                ? Text('Hakuna $label kwenye data ya kipindi hiki.')
                : SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        TextButton(onPressed: () => setLocal(() => chosen.addAll(options)), child: const Text('Chagua zote')),
                        TextButton(onPressed: () => setLocal(chosen.clear), child: const Text('Ondoa zote')),
                      ]),
                      for (final n in options)
                        CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: chosen.contains(n),
                          title: Text(n, style: const TextStyle(fontSize: 13)),
                          onChanged: (v) => setLocal(() => v == true ? chosen.add(n) : chosen.remove(n)),
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
    if (result == null) return;
    // choosing every option is the same as choosing none: "all"
    setState(() {
      _picked
        ..clear()
        ..addAll(result.length == options.length ? const <String>{} : result);
    });
  }

  Widget _card(String title, String value, IconData icon, {bool strong = false}) => Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: strong ? Pal.tint(Colors.blue) : Pal.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: strong ? Pal.primary : Pal.border, width: strong ? 1.6 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 15, color: Pal.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Pal.textSecondary))),
          ]),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
        ]),
      );

  List<Widget> _cards() {
    final t = Map<String, dynamic>.from((_data?['totals'] as Map?) ?? const {});
    final rows = _rows;
    double sum(String k) => rows.fold(0.0, (a, r) => a + _n(r[k]));
    switch (_tab) {
      case 0:
        final people = rows.map((r) => r['employeeId']).toSet().length;
        return [
          _card('Jumla Iliyokatwa', formatTZS(sum('amount')), Icons.remove_circle_outline, strong: true),
          _card('Makato ya Madeni', formatTZS(rows.where((r) => r['isDebt'] == true).fold(0.0, (a, r) => a + _n(r['amount']))), Icons.account_balance_wallet_outlined),
          _card('Wafanyakazi', '$people', Icons.groups_outlined),
          if (!_hideStatutory) _card('Ya Kisheria (NSSF, PAYE)', formatTZS(_n(t['statutory'])), Icons.gavel_outlined),
        ];
      case 1:
        return [
          _card('Jumla ya Posho', formatTZS(sum('amount')), Icons.card_giftcard, strong: true),
          _card('Zinazotozwa Kodi', formatTZS(rows.where((r) => r['taxable'] == true).fold(0.0, (a, r) => a + _n(r['amount']))), Icons.receipt_outlined),
          _card('Zisizotozwa Kodi', formatTZS(rows.where((r) => r['taxable'] != true).fold(0.0, (a, r) => a + _n(r['amount']))), Icons.verified_outlined),
          _card('Wafanyakazi', '${rows.map((r) => r['employeeId']).toSet().length}', Icons.groups_outlined),
        ];
      default:
        return [
          _card('Linalobaki Kulipwa', formatTZS(sum('remaining')), Icons.hourglass_bottom, strong: true),
          _card('Jumla ya Madeni', formatTZS(sum('total')), Icons.account_balance_wallet_outlined),
          _card('Limelipwa', formatTZS(sum('paid')), Icons.check_circle_outline),
          _card('Yanayoendelea / Yaliyoisha', '${t['active'] ?? 0} / ${t['finished'] ?? 0}', Icons.list_alt_outlined),
        ];
    }
  }

  /// Totals per deduction / allowance name (the ones that survive the filters).
  Widget _byName() {
    if (_tab == 2) return const SizedBox.shrink();
    final rows = _rows;
    final key = _tab == 0 ? 'deduction' : 'allowance';
    final acc = <String, double>{};
    for (final r in rows) {
      acc[r[key] as String] = (acc[r[key] as String] ?? 0) + _n(r['amount']);
    }
    if (acc.isEmpty) return const SizedBox.shrink();
    final names = acc.keys.toList()..sort((a, b) => acc[b]!.compareTo(acc[a]!));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final n in names)
          Chip(
            label: Text('$n: ${formatTZS(acc[n]!).replaceFirst('TZS ', '')}', style: const TextStyle(fontSize: 11)),
            backgroundColor: Pal.surfaceAlt,
            side: BorderSide(color: Pal.border),
          ),
      ]),
    );
  }

  Widget _grid() {
    final t = _table();
    return AppDataGrid(
      key: ValueKey('$_tab|$_period|${_picked.length}|${_search.text}|$_hideStatutory'),
      headers: t.headers,
      rows: t.rows,
      totals: t.totals,
      numeric: t.numeric,
      badges: const {
        'Limelipwa lote': Colors.green,
        'Linaendelea': Colors.orange,
        'Inatozwa kodi': Colors.orange,
        'Haitozwi kodi': Colors.blueGrey,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _data == null ? const <Map<String, dynamic>>[] : _rows;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('RIPOTI ZA MAKATO NA POSHO', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Pal.brandText)),
          const SizedBox(height: 4),
          Text('Makato (arrears) na posho (allowances) zilizolipwa kwenye payroll, pamoja na salio la kila deni. Chagua mwezi mmoja au kipindi cha miezi kadhaa.',
              style: TextStyle(fontSize: 11.5, height: 1.35, color: Pal.textSecondary)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: [
            for (var i = 0; i < _tabs.length; i++)
              ChoiceChip(
                label: Text(_tabs[i], style: const TextStyle(fontSize: 11.5)),
                selected: _tab == i,
                onSelected: (_) {
                  setState(() {
                    _tab = i;
                    _data = null;
                    _picked.clear();
                  });
                  _load();
                },
              ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_tab != 2) ...[
                SizedBox(
                  width: 170,
                  child: AppDropdown<String>(
                    label: 'Kuanzia mwezi',
                    value: _month,
                    items: _months,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _month = v;
                        if (_to.compareTo(_month) < 0) _to = _month;
                      });
                      _load();
                    },
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: AppDropdown<String>(
                    label: 'Hadi mwezi',
                    value: _to,
                    items: _months.where((m) => m.compareTo(_month) >= 0).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _to = v);
                      _load();
                    },
                  ),
                ),
              ],
              OutlinedButton.icon(
                onPressed: _data == null ? null : _pickNames,
                icon: const Icon(Icons.filter_list, size: 18),
                label: Text(_picked.isEmpty
                    ? 'Chagua ${['Kato', 'Posho', 'Deni'][_tab]}: Zote'
                    : '${['Kato', 'Posho', 'Deni'][_tab]}: ${_picked.length} vimechaguliwa'),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search, size: 18), hintText: tr('Tafuta jina, namba au aina...')),
                ),
              ),
              if (_tab == 0)
                FilterChip(
                  label: const Text('Ficha NSSF na PAYE', style: TextStyle(fontSize: 11.5)),
                  selected: _hideStatutory,
                  onSelected: (v) => setState(() => _hideStatutory = v),
                ),
              OutlinedButton.icon(
                onPressed: rows.isEmpty ? null : _csv,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Pakua CSV'),
              ),
              OutlinedButton.icon(
                onPressed: rows.isEmpty ? null : _pdf,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('PDF / Print'),
              ),
            ],
          ),
          if (_picked.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final n in (_picked.toList()..sort()))
                InputChip(
                  label: Text(n, style: const TextStyle(fontSize: 11.5)),
                  onDeleted: () => setState(() => _picked.remove(n)),
                ),
              ActionChip(label: const Text('Ondoa vichujio', style: TextStyle(fontSize: 11.5)), onPressed: () => setState(_picked.clear)),
            ]),
          ],
          const SizedBox(height: 14),
          if (_loading && _data == null)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: AppLoadingIndicator(message: 'Inapakua ripoti...'))
          else if (_data == null)
            AppErrorRetryView(message: _error ?? 'Imeshindwa kupakua ripoti.', onRetry: _load)
          else if (rows.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.border)),
              child: Column(children: [
                Icon(Icons.assignment_outlined, size: 40, color: Pal.textMuted),
                const SizedBox(height: 10),
                Text(_tab == 2 ? 'Hakuna madeni yaliyosajiliwa.' : 'Hakuna data kwa kipindi $_period.',
                    textAlign: TextAlign.center, style: TextStyle(color: Pal.textSecondary)),
                const SizedBox(height: 4),
                Text(_tab == 2 ? 'Deni linaonekana hapa likishasajiliwa kwa mfanyakazi.' : 'Ripoti inatokana na payroll iliyoendeshwa; endesha payroll ya mwezi huu au chagua mwezi mwingine.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Pal.textMuted)),
              ]),
            )
          else ...[
            Wrap(spacing: 12, runSpacing: 12, children: _cards()),
            const SizedBox(height: 14),
            _byName(),
            _grid(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
