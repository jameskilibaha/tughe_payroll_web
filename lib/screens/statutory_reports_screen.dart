import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../controllers/statutory_controller.dart';
import '../core/theme.dart';
import '../core/tr_text.dart';
import '../core/translations.dart';
import '../utils/csv_export_web.dart';
import '../utils/formatters.dart';
import 'widgets/app_status_views.dart';
import 'widgets/data_grid.dart';
import 'widgets/form_kit.dart';

/// "Ripoti za Kisheria": what the employer has to file and pay for a month - PAYE (TRA), the pension
/// fund (NSSF / PSSSF), SDL and WCF - and what the whole payroll costs the employer. The figures are the
/// ones the payroll run stored, with the rates of that day.
class StatutoryReportsScreen extends StatefulWidget {
  const StatutoryReportsScreen({super.key});

  @override
  State<StatutoryReportsScreen> createState() => _StatutoryReportsScreenState();
}

class _StatutoryReportsScreenState extends State<StatutoryReportsScreen> {
  final _ctrl = Get.find<StatutoryController>();
  final _search = TextEditingController();
  late String _month;
  int _tab = 0;

  static const _tabs = ['PAYE (TRA)', 'Pensheni (NSSF/PSSSF)', 'SDL na WCF', 'Gharama ya Mwajiri'];

  /// The last 18 months, newest first.
  late final List<String> _months = () {
    final now = DateTime.now();
    return [for (var i = 0; i < 18; i++) _fmt(DateTime(now.year, now.month - i, 1))];
  }();

  static String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // the payroll of the month that has just ended is the one usually being filed
    _month = _fmt(DateTime(now.year, now.month - (now.day < 20 ? 1 : 0), 1));
    _ctrl.loadReport(_month);
    _ctrl.loadSettings();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  double _n(Object? v) => (v as num?)?.toDouble() ?? 0;

  /// (headers, rows, totals) of the open tab. Numbers stay numbers (the CSV writes them with 3 decimals).
  /// [totals] has one entry per header (the first, "No", is empty); [rows] still lack the running number.
  ({List<String> headers, List<List<Object?>> rows, List<Object?> totals, Set<int> numeric}) _tabData(Map<String, dynamic> report) {
    final q = _search.text.trim().toLowerCase();
    final all = (report['rows'] as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    final rows = q.isEmpty ? all : all.where((r) => '${r['name']} ${r['tin']} ${r['employeeNumber']}'.toLowerCase().contains(q)).toList();
    final t = Map<String, dynamic>.from(report['totals'] as Map);
    final fundName = {'NSSF': 'NSSF', 'PSSSF': 'PSSSF', 'NONE': '-'};
    switch (_tab) {
      case 0:
        return (
          headers: ['No', 'Namba', 'Jina', 'TIN', 'Mshahara Ghafi', 'Mapato Yanayotozwa Kodi', 'PAYE'],
          rows: [for (final r in rows) [r['employeeNumber'], r['name'], r['tin'], _n(r['gross']), _n(r['taxableIncome']), _n(r['paye'])]],
          totals: ['', 'JUMLA', '', '', _n(t['gross']), _n(t['taxableIncome']), _n(t['paye'])],
          numeric: {3, 4, 5},
        );
      case 1:
        return (
          headers: ['No', 'Namba', 'Jina', 'Mfuko', 'Namba ya Mfuko', 'Mshahara wa Msingi', 'Mfanyakazi', 'Mwajiri', 'Jumla'],
          rows: [
            for (final r in rows)
              [r['employeeNumber'], r['name'], fundName[r['fund']] ?? r['fund'], r['fundNo'], _n(r['basic']), _n(r['employeePension']), _n(r['employerPension']),
                _n(r['employeePension']) + _n(r['employerPension'])]
          ],
          totals: ['', 'JUMLA', '', '', '', _n(t['basic']), _n(t['employeePension']), _n(t['employerPension']), _n(t['pensionTotal'])],
          numeric: {4, 5, 6, 7},
        );
      case 2:
        return (
          headers: ['No', 'Namba', 'Jina', 'Mshahara Ghafi (msingi wa SDL/WCF)', 'SDL', 'WCF', 'Jumla'],
          rows: [for (final r in rows) [r['employeeNumber'], r['name'], _n(r['gross']), _n(r['sdl']), _n(r['wcf']), _n(r['sdl']) + _n(r['wcf'])]],
          totals: ['', 'JUMLA', '', _n(t['gross']), _n(t['sdl']), _n(t['wcf']), _n(t['sdl']) + _n(t['wcf'])],
          numeric: {2, 3, 4, 5},
        );
      default:
        return (
          headers: ['No', 'Namba', 'Jina', 'Mshahara Ghafi', 'Pensheni ya Mwajiri', 'SDL', 'WCF', 'Gharama ya Mwajiri'],
          rows: [
            for (final r in rows)
              [r['employeeNumber'], r['name'], _n(r['gross']), _n(r['employerPension']), _n(r['sdl']), _n(r['wcf']),
                _n(r['gross']) + _n(r['employerPension']) + _n(r['sdl']) + _n(r['wcf'])]
          ],
          totals: ['', 'JUMLA', '', _n(t['gross']), _n(t['employerPension']), _n(t['sdl']), _n(t['wcf']), _n(t['employerCost'])],
          numeric: {2, 3, 4, 5, 6},
        );
    }
  }

  /// Every row starts with a running number (No); the data rows from [_tabData] begin with the employee number.
  List<List<Object?>> _numbered(List<List<Object?>> rows) => [for (var i = 0; i < rows.length; i++) [i + 1, ...rows[i]]];

  void _export(Map<String, dynamic> report) {
    final d = _tabData(report);
    final names = ['PAYE_TRA', 'Pensheni', 'SDL_WCF', 'Gharama_ya_Mwajiri'];
    final rows = [..._numbered(d.rows), d.totals];
    downloadCsv(filename: 'TUGHE_${names[_tab]}_$_month.csv', headers: d.headers, rows: rows);
  }

  Widget _card(String title, double value, IconData icon, {bool strong = false}) => Container(
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: strong ? Pal.tint(Colors.blue) : Pal.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: strong ? Pal.primary : Pal.border, width: strong ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 15, color: Pal.primary), const SizedBox(width: 6), Expanded(child: Text(title, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Pal.textSecondary)))]),
            const SizedBox(height: 8),
            Text(formatTZS(value), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final report = _ctrl.report.value;
      final confirmed = _ctrl.ratesConfirmed;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('RIPOTI ZA KISHERIA (PAYE, NSSF/PSSSF, SDL, WCF)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Pal.brandText)),
            const SizedBox(height: 4),
            Text('Ratiba za kuwasilisha TRA, NSSF/PSSSF na WCF, na gharama ya jumla ya payroll kwa mwajiri. Zinatokana na payroll iliyoendeshwa.',
                style: TextStyle(fontSize: 11.5, height: 1.35, color: Pal.textSecondary)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: AppDropdown<String>(
                    label: 'Mwezi',
                    value: _month,
                    items: _months,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _month = v);
                      _ctrl.loadReport(v);
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search, size: 18), hintText: tr('Tafuta jina, namba au TIN...')),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: report == null || (report['rows'] as List).isEmpty ? null : () => _export(report),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Pakua CSV'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!confirmed && _ctrl.settings.value != null)
              const FormNotice(
                'Viwango vya kisheria havijathibitishwa. Ripoti hizi zinatumia viwango vya kuanzia; thibitisha kwenye "Mipangilio ya Kisheria" kabla ya kuwasilisha.',
                kind: NoticeKind.info,
              ),
            if (_ctrl.loadingReport.value && report == null)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: AppLoadingIndicator(message: 'Inapakua ripoti...'))
            else if (report == null)
              AppErrorRetryView(message: _ctrl.reportError.value ?? 'Imeshindwa kupakua ripoti.', onRetry: () => _ctrl.loadReport(_month))
            else if ((report['rows'] as List).isEmpty)
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.border)),
                child: Column(children: [
                  Icon(Icons.assignment_outlined, size: 40, color: Pal.textMuted),
                  const SizedBox(height: 10),
                  Text('Hakuna payroll iliyoendeshwa kwa mwezi $_month.', textAlign: TextAlign.center, style: TextStyle(color: Pal.textSecondary)),
                  const SizedBox(height: 4),
                  Text('Endesha payroll ya mwezi huu ndipo ripoti zitaonekana.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Pal.textMuted)),
                ]),
              )
            else ...[
              if ((report['missingTin'] as num? ?? 0) > 0)
                FormNotice('Wafanyakazi ${report['missingTin']} hawana TIN. Ripoti ya PAYE inahitaji TIN ya kila mfanyakazi (weka kwenye "Hali ya Mshahara").'),
              if ((report['missingFundNo'] as num? ?? 0) > 0)
                FormNotice('Wafanyakazi ${report['missingFundNo']} hawana namba ya mfuko wa pensheni (NSSF/PSSSF).'),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _card('Mshahara Ghafi', _n((report['totals'] as Map)['gross']), Icons.payments_outlined),
                _card('PAYE (TRA)', _n((report['totals'] as Map)['paye']), Icons.account_balance_outlined),
                _card('Pensheni (mfanyakazi + mwajiri)', _n((report['totals'] as Map)['pensionTotal']), Icons.savings_outlined),
                _card('SDL', _n((report['totals'] as Map)['sdl']), Icons.school_outlined),
                _card('WCF', _n((report['totals'] as Map)['wcf']), Icons.health_and_safety_outlined),
                _card('Gharama ya Mwajiri', _n((report['totals'] as Map)['employerCost']), Icons.business_center_outlined, strong: true),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 8, children: [
                for (var i = 0; i < _tabs.length; i++)
                  ChoiceChip(label: Text(_tabs[i], style: const TextStyle(fontSize: 11.5)), selected: _tab == i, onSelected: (_) => setState(() => _tab = i)),
              ]),
              const SizedBox(height: 10),
              _table(report),
            ],
            const SizedBox(height: 24),
          ],
        ),
      );
    });
  }

  Widget _table(Map<String, dynamic> report) {
    final d = _tabData(report);
    return AppDataGrid(
      key: ValueKey('$_tab|$_month|${_search.text}'),
      headers: d.headers,
      rows: _numbered(d.rows),
      totals: d.totals,
      numeric: {for (final i in d.numeric) i + 1},
    );
  }
}
