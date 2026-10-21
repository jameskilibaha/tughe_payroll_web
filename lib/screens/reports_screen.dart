import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../controllers/employee_controller.dart';
import '../controllers/month_payroll_controller.dart';
import '../controllers/payroll_trend_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/salary_terms_controller.dart';
import '../models/employee.dart';
import '../models/payroll_calculation_result.dart';
import '../utils/csv_export_web.dart';
import '../utils/formatters.dart';
import '../utils/payroll_calculator.dart';
import '../utils/report_pdf.dart';
import '../utils/salary_slip_from_generated.dart';
import '../utils/persistence_service.dart';
import 'widgets/pagination_bar.dart';
import 'widgets/paylist_panel.dart';
import 'widgets/charts.dart';
import 'widgets/responsive_header_bar.dart';
import '../core/tr_text.dart';
import '../core/translations.dart';
import 'widgets/full_width_scroll.dart';
import 'widgets/tughe_logo.dart';
import '../core/theme.dart';

const _brandBlue = Color(0xFF1E3A8A);
const _slate900 = Color(0xFF0F172A);
const _amber400 = Color(0xFFFBBF24);

enum ReportTab { masterPayroll, traPaye, nssfPension, bankSchedule, deductionsArrears }

const List<String> _swahiliMonths = [
  'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni',
  'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba',
];


class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.onNavigateToSalarySlip});

  final VoidCallback? onNavigateToSalarySlip;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportTab _activeTab = ReportTab.masterPayroll;
  // Columns of the bank paylist (chosen by the user, remembered in this browser).
  Set<String> _paylistKeys = defaultPaylistKeys();
  static const _paylistStoreKey = 'tughe_paylist_columns';
  String _searchTerm = '';
  String _selectedBank = 'ALL';
  String _selectedStation = 'ALL';
  String _sortBy = 'name';
  // Share of basic salary taken as NSSF, e.g. " (10%)" - empty when it differs between employees.
  String _nssfPct = '';
  // The rows currently shown (after search/bank/station filters + sorting) - used by CSV/PDF export.
  List<({Employee employee, PayrollCalculationResult calc})> _lastFiltered = const [];
  int _page = 0;
  int _pageSize = 25;
  String _pageKey = '';

  @override
  void initState() {
    super.initState();
    PersistenceService().readJson(_paylistStoreKey).then((raw) {
      if (raw is List && mounted) setState(() => _paylistKeys = normalizePaylistKeys(raw));
    }).catchError((_) {});
  }

  late int _selectedMonthIndex = DateTime.now().month - 1;
  late int _selectedYear = DateTime.now().year;

  String get _selectedMonthLabel => '${_swahiliMonths[_selectedMonthIndex]} $_selectedYear';

  String get _monthYearKey => '$_selectedYear-${(_selectedMonthIndex + 1).toString().padLeft(2, '0')}';

  /// The people shown in every report: ONLY employees that were processed in
  /// the payroll run of the selected month/year, with their REAL generated
  /// figures (not a live re-calculation of every active employee).
  List<({Employee employee, PayrollCalculationResult calc})> _processedRows() {
    final employeeCtrl = Get.find<EmployeeController>();
    final mp = Get.find<MonthPayrollController>();
    if (mp.loadedFor.value != _monthYearKey) return [];
    final out = <({Employee employee, PayrollCalculationResult calc})>[];
    for (final e in employeeCtrl.employees) {
      final id = e.backendId;
      final rows = id == null ? null : mp.byEmployee[id];
      if (rows == null) continue;
      out.add((employee: e, calc: buildResultFromGeneratedRows(e, rows)));
    }
    return out;
  }

  int Function(({Employee employee, PayrollCalculationResult calc}), ({Employee employee, PayrollCalculationResult calc})) get _comparator {
    switch (_sortBy) {
      case 'id':
        return (a, b) => a.employee.id.toLowerCase().compareTo(b.employee.id.toLowerCase());
      case 'net':
        return (a, b) => b.calc.netSalary.compareTo(a.calc.netSalary);
      case 'gross':
        return (a, b) => b.calc.grossSalary.compareTo(a.calc.grossSalary);
      case 'paye':
        return (a, b) => b.calc.traPayeTax.compareTo(a.calc.traPayeTax);
      case 'nssf':
        return (a, b) => b.calc.nssfDeduction.compareTo(a.calc.nssfDeduction);
      case 'station':
        return (a, b) {
          final c = (a.employee.salaryStatus?.workStation ?? '').compareTo(b.employee.salaryStatus?.workStation ?? '');
          return c != 0 ? c : a.calc.employeeName.compareTo(b.calc.employeeName);
        };
      default:
        return (a, b) => a.calc.employeeName.toLowerCase().compareTo(b.calc.employeeName.toLowerCase());
    }
  }

  String get _filterNote {
    final parts = <String>[
      if (_selectedStation != 'ALL') 'Kituo: $_selectedStation',
      if (_selectedBank != 'ALL') 'Benki: $_selectedBank',
      if (_searchTerm.isNotEmpty) 'Utafutaji: "$_searchTerm"',
    ];
    return parts.join('  |  ');
  }

  Widget _periodBanner() {
    final mp = Get.find<MonthPayrollController>();
    final ready = mp.loadedFor.value == _monthYearKey;
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String text;
    if (!ready || mp.isLoading.value) {
      bg = Pal.surfaceAlt;
      fg = Pal.textSecondary;
      icon = Icons.hourglass_top;
      text = 'Inapakua wafanyakazi wa payroll ya $_selectedMonthLabel...';
    } else if (mp.error.value.isNotEmpty) {
      bg = Pal.tint(Colors.red);
      fg = Pal.fg(Colors.red.shade900);
      icon = Icons.error_outline;
      text = mp.error.value;
    } else if (mp.byEmployee.isEmpty) {
      bg = Pal.tint(Colors.orange);
      fg = Pal.fg(Colors.orange.shade900);
      icon = Icons.info_outline;
      text = 'Hakuna payroll iliyoendeshwa kwa $_selectedMonthLabel. Nenda "Endesha Payroll" kwanza ili wafanyakazi waonekane hapa.';
    } else {
      bg = Pal.tint(Colors.green);
      fg = Pal.fg(Colors.green.shade800);
      icon = Icons.verified;
      text = 'Wafanyakazi ${mp.byEmployee.length} walioshughulikiwa kwenye payroll ya $_selectedMonthLabel.';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, size: 15, color: fg),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.bold))),
        if (mp.error.value.isNotEmpty)
          TextButton(
            onPressed: () => mp.load(_monthYearKey, force: true),
            child: const Text('Jaribu Tena', style: TextStyle(fontSize: 11)),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeeCtrl = Get.find<EmployeeController>();
    final termsCtrl = Get.find<SalaryTermsController>();

    return Obx(() {
      // Load (once per month) who was processed in that month's payroll run.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Get.find<MonthPayrollController>().load(_monthYearKey);
          Get.find<PayrollTrendController>().load();
        }
      });
      final payrollCalculations = _processedRows();

      // Filter options come from the data of THIS month, not from a fixed list.
      final stations = payrollCalculations
          .map((r) => (r.employee.salaryStatus?.workStation ?? '').trim())
          .where((x) => x.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final banks = payrollCalculations
          .map((r) => (r.employee.salaryStatus?.bankName ?? '').trim())
          .where((x) => x.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (_selectedStation != 'ALL' && !stations.contains(_selectedStation)) _selectedStation = 'ALL';
      if (_selectedBank != 'ALL' && !banks.contains(_selectedBank)) _selectedBank = 'ALL';

      final filtered = payrollCalculations.where((r) {
        final q = _searchTerm.toLowerCase();
        final matchesSearch = q.isEmpty ||
            r.employee.id.toLowerCase().contains(q) ||
            r.calc.employeeName.toLowerCase().contains(q);
        final bankName = (r.employee.salaryStatus?.bankName ?? '').trim();
        final matchesBank = _selectedBank == 'ALL' || bankName.toUpperCase() == _selectedBank.toUpperCase();
        final station = (r.employee.salaryStatus?.workStation ?? '').trim();
        final matchesStation = _selectedStation == 'ALL' || station == _selectedStation;
        return matchesSearch && matchesBank && matchesStation;
      }).toList()
        ..sort(_comparator);
      _lastFiltered = filtered;

      // NSSF rate label: "(10%)" only when every employee has the same rate.
      final rates = filtered
          .where((r) => r.calc.basicSalary > 0)
          .map((r) => plainAmount(r.calc.nssfDeduction / r.calc.basicSalary * 100))
          .toSet();
      _nssfPct = rates.length == 1 ? ' (${rates.first}%)' : '';

      double basic = 0, gross = 0, nssf = 0, tra = 0, totalDeductions = 0, net = 0;
      for (final r in filtered) {
        basic += r.calc.basicSalary;
        gross += r.calc.grossSalary;
        nssf += r.calc.nssfDeduction;
        tra += r.calc.traPayeTax;
        totalDeductions += r.calc.totalDeductions;
        net += r.calc.netSalary;
      }

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _headerBanner(),
            const SizedBox(height: 10),
            _periodBanner(),
            const SizedBox(height: 16),
            _summaryCards(filtered.length, gross, tra, nssf, totalDeductions, net),
            const SizedBox(height: 16),
            _reportTabsBar(),
            const SizedBox(height: 16),
            _filterBar(stations, banks),
            const SizedBox(height: 16),
            _chartsPanel(filtered),
            const SizedBox(height: 16),
            _reportTable(filtered, basic, gross, nssf, tra, totalDeductions, net),
          ],
        ),
      );
    });
  }

  // ---------------------------------------------------------------------
  // Header banner: title/subtitle + month selector + CSV/Print actions
  // ---------------------------------------------------------------------

  Widget _headerBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pal.border),
      ),
      child: ResponsiveHeaderBar(
        breakpoint: 760,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _brandBlue, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.bar_chart, color: _amber400, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SEHEMU YA RIPOTI ZA MSHAHARA NA KODI',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Pal.text)),
                  SizedBox(height: 2),
                  Text('Tengeneza, pakua CSV/Excel, na uchapishe ripoti rasmi za TUGHE, TRA, NSSF na Benki.',
                      style: TextStyle(fontSize: 11, color: Pal.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<int>(
              value: _selectedMonthIndex,
              decoration: InputDecoration(isDense: true, labelText: tr('Kipindi')),
              items: List.generate(
                _swahiliMonths.length,
                (i) => DropdownMenuItem(value: i, child: Text(_swahiliMonths[i], style: const TextStyle(fontSize: 11.5))),
              ),
              onChanged: (v) => setState(() => _selectedMonthIndex = v ?? _selectedMonthIndex),
            ),
          ),
          SizedBox(
            width: 110,
            child: DropdownButtonFormField<int>(
              value: _selectedYear,
              decoration: InputDecoration(isDense: true, labelText: tr('Mwaka')),
              items: List.generate(5, (i) => DateTime.now().year - i)
                  .map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 11.5))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedYear = v ?? _selectedYear),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _exportCurrentTabCsv,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
            icon: const Icon(Icons.grid_on, size: 16),
            label: const Text('Pakua CSV (Excel)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: _printReport,
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Chapisha / PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Summary cards
  // ---------------------------------------------------------------------

  Widget _summaryCards(int count, double gross, double tra, double nssf, double totalDeductions, double net) {
    final netNote = _netNote(count, net);
    final cards = [
      _statCard('WAFANYAKAZI', count.toString(), _slate900),
      _statCard('MSHAHARA GHAFU', formatTZS(gross), _brandBlue),
      _statCard('TRA PAYE TAX', formatTZS(tra), Colors.amber.shade800),
      _statCard('NSSF${_nssfPct}', formatTZS(nssf), Colors.blue.shade700),
      _statCard('JUMLA MAKATO', formatTZS(totalDeductions), Colors.red.shade700),
      _statCard('MSHAHARA SAFI (NET)', formatTZS(net), Colors.white, dark: true, note: netNote),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth < 480
          ? 2
          : constraints.maxWidth < 760
              ? 3
              : 6;
      final spacing = 12.0;
      final width = (constraints.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: cards.map((c) => SizedBox(width: width, child: c)).toList(),
      );
    });
  }

  Widget _statCard(String label, String value, Color valueColor, {bool dark = false, String? note}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? Colors.green.shade900 : Pal.surface,
        borderRadius: BorderRadius.circular(12),
        border: dark ? null : Border.all(color: Pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800, color: dark ? Colors.greenAccent.shade100 : Pal.textMuted)),
          const SizedBox(height: 4),
          Text(value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: valueColor)),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(note, style: TextStyle(fontSize: 9, color: dark ? Colors.greenAccent.shade100 : Pal.textMuted)),
          ],
        ],
      ),
    );
  }

  /// "Wastani X" and the change against the previous month (when both months are known).
  String _netNote(int count, double net) {
    if (count == 0) return '';
    final parts = <String>['Wastani ${formatAmount(net / count)}'];
    final unfiltered = _searchTerm.isEmpty && _selectedBank == 'ALL' && _selectedStation == 'ALL';
    if (unfiltered && Get.isRegistered<PayrollTrendController>()) {
      final months = Get.find<PayrollTrendController>().months;
      MonthTotals? find(String key) {
        for (final m in months) {
          if (m.monthYear == key) return m;
        }
        return null;
      }
      final prevDate = DateTime(_selectedYear, _selectedMonthIndex);
      final prev = find('${prevDate.year}-${prevDate.month.toString().padLeft(2, '0')}');
      if (prev != null && prev.net > 0) {
        final delta = (net - prev.net) / prev.net * 100;
        parts.add('${delta >= 0 ? '▲' : '▼'} ${delta.abs().toStringAsFixed(3)}% vs ${shortMonth(prevDate.month)}');
      }
    }
    return parts.join(' • ');
  }

  // ---------------------------------------------------------------------
  // Report tabs
  // ---------------------------------------------------------------------

  Widget _reportTabsBar() {
    final tabs = [
      (ReportTab.masterPayroll, Icons.description_outlined, '1. Ripoti Kuu ya Payroll (Master Sheet)'),
      (ReportTab.traPaye, Icons.receipt_long_outlined, '2. Kodi ya TRA (PAYE Tax)'),
      (ReportTab.nssfPension, Icons.verified_user_outlined, '3. Michango ya NSSF / PSSSF'),
      (ReportTab.bankSchedule, Icons.account_balance_outlined, '4. Ratiba ya Benki (Bank Paylist)'),
      (ReportTab.deductionsArrears, Icons.filter_list, '5. Makato Mengine & Arrears'),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pal.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tabs.map((t) {
          final isActive = _activeTab == t.$1;
          return ElevatedButton.icon(
            onPressed: () => setState(() => _activeTab = t.$1),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? _brandBlue : Colors.transparent,
              foregroundColor: isActive ? Colors.white : Colors.black87,
              elevation: isActive ? 2 : 0,
              shadowColor: Colors.transparent,
            ),
            icon: Icon(t.$2, size: 15),
            label: Text(t.$3, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Filter bar
  // ---------------------------------------------------------------------

  Widget _filterBar(List<String> stations, List<String> banks) {
    const sortOptions = <String, String>{
      'name': 'Jina (A-Z)',
      'id': 'PF ID',
      'net': 'Net Pay (kubwa → ndogo)',
      'gross': 'Mshahara Ghafu (kubwa → ndogo)',
      'paye': 'Kodi ya PAYE (kubwa → ndogo)',
      'nssf': 'NSSF (kubwa → ndogo)',
      'station': 'Kituo cha Kazi',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pal.border),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              decoration: InputDecoration(
                  isDense: true, prefixIcon: Icon(Icons.search, size: 16), hintText: tr('Tafuta kwa PF ID au Jina...')),
              onChanged: (v) => setState(() => _searchTerm = v),
            ),
          ),
          if (stations.length > 1)
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String>(
                value: _selectedStation,
                isExpanded: true,
                decoration: InputDecoration(isDense: true, labelText: tr('Kituo cha Kazi')),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('Vituo Vyote', style: TextStyle(fontSize: 11.5))),
                  for (final st in stations)
                    DropdownMenuItem(value: st, child: Text(st, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _selectedStation = v ?? 'ALL'),
              ),
            ),
          if (_activeTab == ReportTab.bankSchedule && banks.isNotEmpty)
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                value: _selectedBank,
                isExpanded: true,
                decoration: InputDecoration(isDense: true, labelText: tr('Filter kwa Benki')),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('Benki Zote', style: TextStyle(fontSize: 11.5))),
                  for (final b in banks) DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 11.5))),
                ],
                onChanged: (v) => setState(() => _selectedBank = v ?? 'ALL'),
              ),
            ),
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<String>(
              value: _sortBy,
              isExpanded: true,
              decoration: InputDecoration(isDense: true, labelText: tr('Panga kwa')),
              items: [
                for (final e in sortOptions.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 11.5))),
              ],
              onChanged: (v) => setState(() => _sortBy = v ?? 'name'),
            ),
          ),
          if (_searchTerm.isNotEmpty || _selectedStation != 'ALL' || _selectedBank != 'ALL')
            TextButton.icon(
              onPressed: () => setState(() {
                _searchTerm = '';
                _selectedStation = 'ALL';
                _selectedBank = 'ALL';
              }),
              icon: const Icon(Icons.filter_alt_off, size: 14),
              label: const Text('Futa Vichujio', style: TextStyle(fontSize: 11)),
            ),
          if (widget.onNavigateToSalarySlip != null)
            TextButton.icon(
              onPressed: widget.onNavigateToSalarySlip,
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: const Text('Tazama / Chapisha Hati za Mishahara (Payslips)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Charts of the CURRENT (filtered) report
  // ---------------------------------------------------------------------

  Widget _chartsPanel(List<({Employee employee, PayrollCalculationResult calc})> filtered) {
    if (filtered.isEmpty) return const SizedBox.shrink();
    double gross = 0, net = 0, paye = 0, nssf = 0, other = 0;
    final byStation = <String, double>{};
    final byBank = <String, double>{};
    for (final r in filtered) {
      gross += r.calc.grossSalary;
      net += r.calc.netSalary;
      paye += r.calc.traPayeTax;
      nssf += r.calc.nssfDeduction;
      other += r.calc.totalOtherDeductions;
      final st = (r.employee.salaryStatus?.workStation ?? '').trim();
      final bk = (r.employee.salaryStatus?.bankName ?? '').trim();
      byStation[st.isEmpty ? '-' : st] = (byStation[st.isEmpty ? '-' : st] ?? 0) + r.calc.netSalary;
      byBank[bk.isEmpty ? '-' : bk] = (byBank[bk.isEmpty ? '-' : bk] ?? 0) + r.calc.netSalary;
    }
    final palette = [
      Pal.chartBlue, Color(0xFF7C3AED), Color(0xFF059669), Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF0891B2),
    ];
    List<ChartSlice> ranked(Map<String, double> m) {
      final e = m.entries.where((x) => x.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
      return [for (var i = 0; i < e.length && i < 6; i++) ChartSlice(e[i].key, e[i].value, palette[i % palette.length])];
    }

    final cards = <Widget>[
      ChartCard(
        title: 'Mgawanyo wa Mshahara Ghafu',
        subtitle: 'Wafanyakazi ${filtered.length} • $_selectedMonthLabel',
        child: DonutChart(
          centerTop: formatAmount(gross),
          centerBottom: 'Ghafi',
          slices: [
            ChartSlice('Mshahara Safi (Net)', net, const Color(0xFF059669)),
            ChartSlice('Kodi ya TRA (PAYE)', paye, const Color(0xFF7C3AED)),
            ChartSlice('NSSF', nssf, Pal.chartBlue),
            ChartSlice('Makato Mengine', other, const Color(0xFFD97706)),
          ],
        ),
      ),
      ChartCard(title: 'Net Pay kwa Kituo cha Kazi (Top 6)', child: BarList(items: ranked(byStation))),
      ChartCard(title: 'Net Pay kwa Benki', subtitle: 'Kiasi cha kutuma kila benki', child: BarList(items: ranked(byBank))),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pal.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: Icon(Icons.pie_chart_outline, color: Pal.brandText, size: 20),
          title: Text('Grafu za Ripoti (Charts)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Pal.brandText)),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 680 ? 2 : 1);
              const gap = 14.0;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(spacing: gap, runSpacing: gap, children: [for (final card in cards) SizedBox(width: w, child: card)]);
            }),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Report table (columns/rows vary per active tab)
  // ---------------------------------------------------------------------

  String get _tabTitle {
    switch (_activeTab) {
      case ReportTab.masterPayroll:
        return 'RIPOTI KUU YA MSHAHARA NA MAKATO (MASTER PAYROLL SHEET)';
      case ReportTab.traPaye:
        return 'RATIBA YA KODI YA MAPATO TRA (PAYE TAX SCHEDULE)';
      case ReportTab.nssfPension:
        return 'RATIBA YA MICHANGO YA MIFUKO YA HIFADHI YA JAMII (NSSF/PSSSF)';
      case ReportTab.bankSchedule:
        return 'RATIBA YA MALIPO YA MIKUPO BENKI (BANK DISBURSEMENT SCHEDULE)';
      case ReportTab.deductionsArrears:
        return 'RIPOTI YA MAKATO NA ARREARS ZA WAFANYAKAZI';
    }
  }

  List<DataColumn> get _columns {
    const base = [DataColumn(label: Text('PF ID')), DataColumn(label: Text('Jina la Mfanyakazi'))];
    switch (_activeTab) {
      case ReportTab.masterPayroll:
        return [
          ...base,
          const DataColumn(label: Text('Kituo cha Kazi')),
          const DataColumn(label: Text('Basic (TZS)'), numeric: true),
          const DataColumn(label: Text('Gross (TZS)'), numeric: true),
          DataColumn(label: Text('NSSF${_nssfPct}'), numeric: true),
          const DataColumn(label: Text('TRA PAYE'), numeric: true),
          const DataColumn(label: Text('Makato Mengine'), numeric: true),
          const DataColumn(label: Text('Jumla Makato'), numeric: true),
          const DataColumn(label: Text('Net Pay (TZS)'), numeric: true),
        ];
      case ReportTab.traPaye:
        return [
          ...base,
          const DataColumn(label: Text('Cheo / Occupation')),
          const DataColumn(label: Text('Mshahara Ghafu'), numeric: true),
          const DataColumn(label: Text('Makato ya NSSF'), numeric: true),
          const DataColumn(label: Text('Kinachokatwa Kodi'), numeric: true),
          const DataColumn(label: Text('Kodi ya TRA'), numeric: true),
        ];
      case ReportTab.nssfPension:
        return [
          ...base,
          const DataColumn(label: Text('Mshahara Ghafu'), numeric: true),
          DataColumn(label: Text('Mchango Mfanyakazi${_nssfPct}'), numeric: true),
          DataColumn(label: Text('Mchango Mwajiri${_nssfPct}'), numeric: true),
          const DataColumn(label: Text('Jumla Mchango'), numeric: true),
        ];
      case ReportTab.bankSchedule:
        return [
          ...base,
          const DataColumn(label: Text('Jina la Benki')),
          const DataColumn(label: Text('Namba ya Akaunti')),
          const DataColumn(label: Text('Kiasi cha Kutuma (Net)'), numeric: true),
        ];
      case ReportTab.deductionsArrears:
        return [
          ...base,
          DataColumn(label: Text('NSSF${_nssfPct}'), numeric: true),
          const DataColumn(label: Text('TRA PAYE'), numeric: true),
          const DataColumn(label: Text('Madeni & Arrears'), numeric: true),
          const DataColumn(label: Text('Jumla Makato'), numeric: true),
        ];
    }
  }

  DataRow _row(Employee employee, PayrollCalculationResult calc) {
    Widget cell(String text, {Color? color, bool bold = false}) => Text(text,
        style: TextStyle(fontSize: 11, color: color ?? Pal.text, fontWeight: bold ? FontWeight.bold : null));

    final baseCells = [
      DataCell(Text(employee.id, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Pal.brandText))),
      DataCell(Text(calc.employeeName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
    ];

    switch (_activeTab) {
      case ReportTab.masterPayroll:
        final otherDeductions = calc.totalDeductions - (calc.nssfDeduction + calc.traPayeTax);
        return DataRow(cells: [
          ...baseCells,
          DataCell(cell(employee.salaryStatus?.workStation ?? '-')),
          DataCell(cell(formatTZS(calc.basicSalary))),
          DataCell(cell(formatTZS(calc.grossSalary), color: Pal.brandText, bold: true)),
          DataCell(cell(formatTZS(calc.nssfDeduction), color: Pal.fg(Colors.blue.shade700))),
          DataCell(cell(formatTZS(calc.traPayeTax), color: Pal.fg(Colors.amber.shade800))),
          DataCell(cell(formatTZS(otherDeductions))),
          DataCell(cell(formatTZS(calc.totalDeductions), color: Pal.fg(Colors.red.shade700), bold: true)),
          DataCell(cell(formatTZS(calc.netSalary), color: Pal.fg(Colors.green.shade700), bold: true)),
        ]);
      case ReportTab.traPaye:
        return DataRow(cells: [
          ...baseCells,
          DataCell(cell(employee.salaryStatus?.occupation ?? '-')),
          DataCell(cell(formatTZS(calc.grossSalary))),
          DataCell(cell(formatTZS(calc.nssfDeduction), color: Pal.fg(Colors.blue.shade700))),
          DataCell(cell(formatTZS(calc.taxableSalary))),
          DataCell(cell(formatTZS(calc.traPayeTax), color: Pal.fg(Colors.amber.shade800), bold: true)),
        ]);
      case ReportTab.nssfPension:
        return DataRow(cells: [
          ...baseCells,
          DataCell(cell(formatTZS(calc.grossSalary))),
          DataCell(cell(formatTZS(calc.nssfDeduction), color: Pal.fg(Colors.blue.shade700), bold: true)),
          DataCell(cell(formatTZS(calc.nssfDeduction))),
          DataCell(cell(formatTZS(calc.nssfDeduction * 2), color: Pal.brandText, bold: true)),
        ]);
      case ReportTab.bankSchedule:
        return DataRow(cells: [
          ...baseCells,
          DataCell(cell(employee.salaryStatus?.bankName ?? '-', bold: true)),
          DataCell(Text(employee.salaryStatus?.bankAccountNumber ?? '-',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
          DataCell(cell(formatTZS(calc.netSalary), color: Pal.fg(Colors.green.shade700), bold: true)),
        ]);
      case ReportTab.deductionsArrears:
        final otherDeductions = calc.totalDeductions - (calc.nssfDeduction + calc.traPayeTax);
        return DataRow(cells: [
          ...baseCells,
          DataCell(cell(formatTZS(calc.nssfDeduction), color: Pal.fg(Colors.blue.shade700))),
          DataCell(cell(formatTZS(calc.traPayeTax), color: Pal.fg(Colors.amber.shade800))),
          DataCell(cell(formatTZS(otherDeductions))),
          DataCell(cell(formatTZS(calc.totalDeductions), color: Pal.fg(Colors.red.shade700), bold: true)),
        ]);
    }
  }

  DataRow _totalsRow(double basic, double gross, double nssf, double tra, double totalDeductions, double net) {
    Widget t(String text, {Color color = Colors.white}) =>
        Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color));

    List<DataCell> cells;
    switch (_activeTab) {
      case ReportTab.masterPayroll:
        cells = [
          DataCell(t('-')),
          DataCell(t(formatTZS(basic))),
          DataCell(t(formatTZS(gross), color: _amber400)),
          DataCell(t(formatTZS(nssf))),
          DataCell(t(formatTZS(tra), color: _amber400)),
          DataCell(t(formatTZS(totalDeductions - (nssf + tra)))),
          DataCell(t(formatTZS(totalDeductions), color: Colors.red.shade300)),
          DataCell(t(formatTZS(net), color: Colors.green.shade300)),
        ];
        break;
      case ReportTab.traPaye:
        cells = [
          DataCell(t('-')),
          DataCell(t(formatTZS(gross))),
          DataCell(t(formatTZS(nssf))),
          DataCell(t(formatTZS(_lastFiltered.fold<double>(0, (sum, r) => sum + r.calc.taxableSalary)))),
          DataCell(t(formatTZS(tra), color: _amber400)),
        ];
        break;
      case ReportTab.nssfPension:
        cells = [
          DataCell(t(formatTZS(gross))),
          DataCell(t(formatTZS(nssf), color: Colors.blue.shade200)),
          DataCell(t(formatTZS(nssf))),
          DataCell(t(formatTZS(nssf * 2), color: _amber400)),
        ];
        break;
      case ReportTab.bankSchedule:
        cells = [
          DataCell(t('-')),
          DataCell(t('-')),
          DataCell(t(formatTZS(net), color: Colors.green.shade300)),
        ];
        break;
      case ReportTab.deductionsArrears:
        cells = [
          DataCell(t(formatTZS(nssf))),
          DataCell(t(formatTZS(tra))),
          DataCell(t(formatTZS(totalDeductions - (nssf + tra)))),
          DataCell(t(formatTZS(totalDeductions), color: Colors.red.shade300)),
        ];
        break;
    }

    return DataRow(
      color: WidgetStateProperty.all(_slate900),
      cells: [
        DataCell(Text('JUMLA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _amber400))),
        DataCell(Text('KUU (TOTALS)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _amber400))),
        ...cells,
      ],
    );
  }

  Widget _reportTable(
    List<({Employee employee, PayrollCalculationResult calc})> filtered,
    double basic,
    double gross,
    double nssf,
    double tra,
    double totalDeductions,
    double net,
  ) {
    if (_activeTab == ReportTab.bankSchedule) {
      return PaylistPanel(
        rows: filtered,
        monthLabel: _selectedMonthLabel,
        keys: _paylistKeys,
        onKeysChanged: (k) {
          setState(() => _paylistKeys = k);
          PersistenceService().writeJson(_paylistStoreKey, k.toList()).catchError((_) {});
        },
      );
    }
    // Back to page 1 whenever the report, month, search or bank changes.
    final pageKey = '${_activeTab.index}|$_searchTerm|$_selectedBank|$_selectedStation|$_sortBy|$_monthYearKey|${filtered.length}';
    if (pageKey != _pageKey) {
      _pageKey = pageKey;
      _page = 0;
    }
    final visible = pageSlice(filtered, _page, _pageSize);

    return Container(
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pal.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: _slate900,
            // The logo stands on BOTH sides of the title (left and right).
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const TugheLogo(size: 44, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('TANZANIA UNION OF GOVERNMENT AND HEALTH EMPLOYEES (TUGHE)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _amber400, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('$_tabTitle - ${_selectedMonthLabel.toUpperCase()}',
                          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(4)),
                        child: Text('Jumla: ${filtered.length} Records',
                            style: TextStyle(color: Colors.blue.shade200, fontSize: 10, fontFamily: 'monospace')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const TugheLogo(size: 44, radius: 10),
              ],
            ),
          ),
          filtered.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Hakuna Rekodi Zinazolingana.', style: TextStyle(color: Pal.textMuted))),
                )
              : FullWidthScroll(
 child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Pal.surfaceAlt),
                    headingRowHeight: 42,
                    dataRowMinHeight: 40,
                    dataRowMaxHeight: 52,
                    columnSpacing: 24,
                    horizontalMargin: 16,
                    dividerThickness: 0.6,
                    columns: _columns,
                    rows: [
                      // One page of rows at a time; the TOTALS row always covers ALL records.
                      for (final r in visible) _row(r.employee, r.calc),
                      _totalsRow(basic, gross, nssf, tra, totalDeductions, net),
                    ],
                  ),
                ),
          if (filtered.isNotEmpty)
            PaginationBar(
              total: filtered.length,
              page: _page,
              pageSize: _pageSize,
              onPageChanged: (p) => setState(() => _page = p),
              onPageSizeChanged: (n) => setState(() {
                _pageSize = n;
                _page = 0;
              }),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // CSV export per active tab
  // ---------------------------------------------------------------------

  /// Headers + rows (raw numbers) of the ACTIVE report for exactly the rows on
  /// screen (search/bank/station filters and sorting applied). One source for
  /// both the CSV download and the PDF/print output.
  ({String title, String file, List<String> headers, List<List<Object?>> rows}) _reportData() {
    final rowsData = _lastFiltered;
    final other = (PayrollCalculationResult c) => c.totalDeductions - (c.nssfDeduction + c.traPayeTax);
    switch (_activeTab) {
      case ReportTab.masterPayroll:
        return (
          title: _tabTitle,
          file: 'Master_Payroll_Report',
          headers: ['PF ID', 'Jina Kamili', 'Cheo', 'Kituo cha Kazi', 'Mshahara wa Msingi (Basic)', 'Posho (Allowances)',
            'Mshahara Ghafu (Gross)', 'NSSF$_nssfPct', 'TRA PAYE Tax', 'Makato Mengine (Arrears)', 'Jumla ya Makato', 'Mshahara Safi (Net Pay)'],
          rows: [
            for (final r in rowsData)
              [
                r.employee.id, r.calc.employeeName, r.employee.salaryStatus?.occupation ?? '-',
                r.employee.salaryStatus?.workStation ?? '-', r.calc.basicSalary, r.calc.totalAllowances, r.calc.grossSalary,
                r.calc.nssfDeduction, r.calc.traPayeTax, other(r.calc), r.calc.totalDeductions, r.calc.netSalary,
              ],
          ],
        );
      case ReportTab.traPaye:
        return (
          title: _tabTitle,
          file: 'TRA_PAYE_Tax_Report',
          headers: ['PF ID', 'Jina Kamili', 'Cheo', 'Mshahara wa Msingi', 'Makato ya NSSF', 'Kiasi Kinachokatwa Kodi', 'Kodi ya TRA (PAYE)'],
          rows: [
            for (final r in rowsData)
              [
                r.employee.id, r.calc.employeeName, r.employee.salaryStatus?.occupation ?? '-', r.calc.basicSalary,
                r.calc.nssfDeduction, r.calc.taxableSalary, r.calc.traPayeTax,
              ],
          ],
        );
      case ReportTab.nssfPension:
        return (
          title: _tabTitle,
          file: 'NSSF_PSSSF_Pension_Report',
          headers: ['PF ID', 'Jina Kamili', 'Mshahara wa Msingi', 'Mchango wa Mfanyakazi$_nssfPct', 'Mchango wa Mwajiri$_nssfPct', 'Jumla ya Mfuko'],
          rows: [
            for (final r in rowsData)
              [r.employee.id, r.calc.employeeName, r.calc.basicSalary, r.calc.nssfDeduction, r.calc.nssfDeduction, r.calc.nssfDeduction * 2],
          ],
        );
      case ReportTab.bankSchedule:
        final pl = buildPaylist(rowsData, _paylistKeys, _selectedMonthLabel);
        return (title: _tabTitle, file: 'Bank_Paylist_Schedule', headers: pl.headers, rows: pl.rows);
      case ReportTab.deductionsArrears:
        return (
          title: _tabTitle,
          file: 'Deductions_Arrears_Report',
          headers: ['PF ID', 'Jina Kamili', 'Makato ya NSSF', 'Makato ya TRA PAYE', 'Madeni & Arrears', 'Jumla ya Makato'],
          rows: [
            for (final r in rowsData)
              [r.employee.id, r.calc.employeeName, r.calc.nssfDeduction, r.calc.traPayeTax, other(r.calc), r.calc.totalDeductions],
          ],
        );
    }
  }

  /// "JUMLA" row: sum of every column whose values are all numbers.
  List<Object?> _totalsOf(List<String> headers, List<List<Object?>> rows) {
    return [
      for (var c = 0; c < headers.length; c++)
        c == 0
            ? 'JUMLA'
            : (rows.isNotEmpty && rows.every((r) => r[c] is num)
                ? rows.fold<double>(0, (sum, r) => sum + (r[c] as num).toDouble())
                : ''),
    ];
  }

  void _exportCurrentTabCsv() {
    final data = _reportData();
    final monthTag = _selectedMonthLabel.replaceAll(' ', '_');
    downloadCsv(
      filename: '${data.file}_$monthTag.csv',
      headers: data.headers,
      rows: [...data.rows, if (data.rows.isNotEmpty) _totalsOf(data.headers, data.rows)],
    );
  }

  Future<void> _printReport() async {
    final data = _reportData();
    await printReportPdf(
      title: data.title,
      periodLabel: _selectedMonthLabel,
      headers: data.headers,
      rows: data.rows,
      totals: data.rows.isEmpty ? null : _totalsOf(data.headers, data.rows),
      filterNote: _filterNote,
    );
  }
}
