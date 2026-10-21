import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../controllers/employee_controller.dart';
import '../controllers/month_payroll_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/payroll_trend_controller.dart';
import '../controllers/salary_terms_controller.dart';
import '../models/employee.dart';
import '../models/payroll_calculation_result.dart';
import '../models/tra_salary_term.dart';
import '../utils/formatters.dart';
import '../utils/payroll_calculator.dart';
import '../utils/salary_slip_from_generated.dart';
import 'widgets/app_status_views.dart';
import 'widgets/charts.dart';
import 'widgets/tughe_logo.dart';
import 'widgets/full_width_scroll.dart';
import '../core/tr_text.dart';
import '../core/theme.dart';

const _brandBlue = Color(0xFF1E3A8A);
const _slate900 = Color(0xFF0F172A);

const List<String> _dashMonths = [
  'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni',
  'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba',
];

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onSelectEmployeeForSlip});

  final void Function(Employee) onSelectEmployeeForSlip;

  @override
  Widget build(BuildContext context) {
    final nav = Get.find<NavigationController>();
    final employeeCtrl = Get.find<EmployeeController>();
    final termsCtrl = Get.find<SalaryTermsController>();

    return Obx(() {
      if (employeeCtrl.isLoading.value) {
        return const AppLoadingIndicator(message: 'Inapakua taarifa za dashibodi...');
      }
      final employees = employeeCtrl.employees;
      final traTerms = termsCtrl.traTerms.toList();
      final active = employees.where((e) => e.status == 'Active').toList();
      final blocked = employees.where((e) => e.status == 'Blocked').toList();

      double totalGross = 0, totalAllowances = 0, totalPaye = 0, totalNssf = 0;
      double totalOtherDeductions = 0, totalNet = 0;

      // Current month's payroll: when it has been run, the figures below are the
      // REAL ones from the server; otherwise they are estimates for active staff.
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final mp = Get.find<MonthPayrollController>();
      WidgetsBinding.instance.addPostFrameCallback((_) => mp.load(monthKey));
      final trend = Get.find<PayrollTrendController>();
      WidgetsBinding.instance.addPostFrameCallback((_) => trend.load());
      final monthReady = mp.loadedFor.value == monthKey && !mp.isLoading.value;
      final processedIds = monthReady ? mp.byEmployee.keys.toSet() : <int>{};
      final hasActual = processedIds.isNotEmpty;

      final eligible = active.where((e) => e.salaryStatus != null).toList();
      final withoutStatus = active.where((e) => e.salaryStatus == null).length;
      final calcList = hasActual
          ? employees
              .where((e) => e.backendId != null && processedIds.contains(e.backendId))
              .map((e) => buildResultFromGeneratedRows(e, mp.byEmployee[e.backendId]!))
              .toList()
          : active.map((e) => calculateEmployeePayroll(e, traTerms: traTerms)).toList();

      for (final calc in calcList) {
        totalGross += calc.grossSalary;
        totalAllowances += calc.totalAllowances;
        totalPaye += calc.traPayeTax;
        totalNssf += calc.nssfDeduction;
        totalOtherDeductions += calc.totalOtherDeductions;
        totalNet += calc.netSalary;
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _banner(nav),
            const SizedBox(height: 16),
            _payrollStatusCard(
              nav: nav,
              monthLabel: '${_dashMonths[now.month - 1]} ${now.year}',
              loading: !monthReady,
              error: mp.error.value,
              processed: processedIds.length,
              eligible: eligible.length,
              withoutStatus: withoutStatus,
              blocked: blocked.length,
            ),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final cards = [
                _statCard(
                  label: 'WAFANYAKAZI WOTE',
                  value: employees.length.toString(),
                  valueColor: Pal.brandText,
                  icon: Icons.groups_outlined,
                  iconBg: Pal.tint(Colors.blue),
                  iconColor: Pal.brandText,
                  footer: 'Fungiwa: ${blocked.length}',
                  footerAction: ('Orodha', () => nav.goTo('registration')),
                  trailing: '${active.length} Hai',
                ),
                _statCard(
                  label: 'NET PAY (MSHAHARA SAFI)',
                  value: formatTZS(totalNet),
                  valueColor: Pal.text,
                  icon: Icons.account_balance_wallet_outlined,
                  iconBg: Pal.tint(Colors.green),
                  iconColor: Pal.fg(Colors.green.shade700),
                  footer: 'Ghafi: ${formatTZS(totalGross)} • ${hasActual ? 'halisi' : 'makadirio'}',
                ),
                _statCard(
                  label: 'KODI YA TRA (PAYE)',
                  value: formatTZS(totalPaye),
                  valueColor: Pal.fg(Colors.purple.shade900),
                  icon: Icons.calculate_outlined,
                  iconBg: Pal.tint(Colors.purple),
                  iconColor: Pal.fg(Colors.purple.shade800),
                  footer: 'NSSF/PSSSF: ${formatTZS(totalNssf)}',
                  footerAction: ('Fomula', () => nav.goTo('settings_salary_terms')),
                ),
                _statCard(
                  label: 'POSHO NA MAKATO',
                  value: formatTZS(totalAllowances),
                  valueColor: Pal.fg(Colors.amber.shade800),
                  icon: Icons.card_giftcard,
                  iconBg: Pal.tint(Colors.amber),
                  iconColor: Pal.fg(Colors.amber.shade800),
                  footer: 'Arrears: ${formatTZS(totalOtherDeductions)}',
                  footerAction: ('Simamia', () => nav.goTo('allowances')),
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: i == cards.length - 1 ? 0 : 16),
                        child: cards[i],
                      ),
                  ],
                );
              }

              // IntrinsicHeight + stretch keeps every card in the row the same
              // height (the tallest one) without forcing a fixed aspect ratio
              // that can clip content on narrower desktop widths.
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != cards.length - 1) const SizedBox(width: 16),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            _chartsSection(
              calcList: calcList,
              hasActual: hasActual,
              employees: employees.toList(),
              active: active,
              trend: trend,
            ),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final table = _employeeTable(employees.take(5).toList(), traTerms, nav);
              final panel = _traPanel(traTerms, nav);
              if (isNarrow) {
                return Column(children: [table, const SizedBox(height: 16), panel]);
              }
              // No IntrinsicHeight here: the table uses a LayoutBuilder (to fill the
              // whole card width) which cannot be measured intrinsically.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: table),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: panel),
                ],
              );
            }),
          ],
        ),
      );
    });
  }

  /// Where this month's payroll stands, plus things that need attention.
  // ---------------------------------------------------------------------
  // Charts
  // ---------------------------------------------------------------------

  // A getter (not const): the first colour follows the light/dark theme.
  static List<Color> get _palette => [
    Pal.chartBlue, Color(0xFF7C3AED), Color(0xFF059669), Color(0xFFD97706),
    Color(0xFFDC2626), Color(0xFF0891B2), Color(0xFFDB2777), Color(0xFF65A30D),
  ];

  /// name -> total, biggest first, at most [top] entries (the rest grouped as "Nyingine").
  List<ChartSlice> _rank(Map<String, double> totals, {int top = 5}) {
    final entries = totals.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    final out = <ChartSlice>[];
    for (var i = 0; i < entries.length && i < top; i++) {
      out.add(ChartSlice(entries[i].key, entries[i].value, _palette[i % _palette.length]));
    }
    final rest = entries.skip(top).fold<double>(0, (s, e) => s + e.value);
    if (rest > 0) out.add(ChartSlice('Nyingine', rest, Colors.blueGrey.shade300));
    return out;
  }

  Widget _chartsSection({
    required List<PayrollCalculationResult> calcList,
    required bool hasActual,
    required List<Employee> employees,
    required List<Employee> active,
    required PayrollTrendController trend,
  }) {
    // ---- this month: where the gross salary goes ----
    double gross = 0, net = 0, paye = 0, nssf = 0, other = 0;
    final allowanceTotals = <String, double>{};
    final arrearTotals = <String, double>{};
    for (final c in calcList) {
      gross += c.grossSalary;
      net += c.netSalary;
      paye += c.traPayeTax;
      nssf += c.nssfDeduction;
      other += c.totalOtherDeductions;
      for (final a in c.allowanceDetails) {
        allowanceTotals[a.name] = (allowanceTotals[a.name] ?? 0) + a.amount;
      }
      for (final a in c.arrearsDetails) {
        arrearTotals[a.name] = (arrearTotals[a.name] ?? 0) + a.amount;
      }
    }
    final sourceNote = hasActual ? 'Payroll halisi ya mwezi huu' : 'Makadirio (payroll ya mwezi huu bado haijaendeshwa)';

    // ---- staff ----
    final blockedCount = employees.where((e) => e.status == 'Blocked').length;
    final activeNoStatus = active.where((e) => e.salaryStatus == null).length;
    final activeWithStatus = active.length - activeNoStatus;

    final genderCounts = <String, double>{};
    for (final e in active) {
      final g = e.gender.isEmpty ? '-' : e.gender;
      genderCounts[g] = (genderCounts[g] ?? 0) + 1;
    }
    Color genderColor(String g) {
      final l = g.toLowerCase();
      if (l.startsWith('m') || l.startsWith('k') && l.contains('ume')) return const Color(0xFF1E3A8A);
      if (l.startsWith('f') || l.contains('ke')) return const Color(0xFFDB2777);
      return Colors.blueGrey;
    }

    final stationCounts = <String, double>{};
    for (final e in active) {
      final st = e.salaryStatus?.workStation.trim() ?? '';
      if (st.isEmpty) continue;
      stationCounts[st] = (stationCounts[st] ?? 0) + 1;
    }

    // basic salary bands
    const bands = <(String, double, double)>[
      ('< 500K', 0, 500000),
      ('500K-1M', 500000, 1000000),
      ('1M-2M', 1000000, 2000000),
      ('2M-3M', 2000000, 3000000),
      ('> 3M', 3000000, double.infinity),
    ];
    final bandItems = <ColumnItem>[
      for (final b in bands)
        ColumnItem(
          b.$1,
          active.where((e) {
            final basic = e.salaryStatus?.basicSalary;
            return basic != null && basic >= b.$2 && basic < b.$3;
          }).length.toDouble(),
          tooltip: '${b.$1}',
        ),
    ];

    // ---- last 6 months ----
    final trendItems = trend.months
        .map((m) => ColumnItem(
              shortMonth(m.month),
              m.net,
              tooltip: '${m.monthYear}\nNet: ${formatTZS(m.net)}\nGhafi: ${formatTZS(m.gross)}\nPAYE: ${formatTZS(m.paye)}\nNSSF: ${formatTZS(m.nssf)}\nWafanyakazi: ${m.employees}',
            ))
        .toList();
    final trendHasData = trend.months.any((m) => m.net > 0);

    final cards = <Widget>[
      ChartCard(
        title: 'Mgawanyo wa Mshahara Ghafi (mwezi huu)',
        subtitle: sourceNote,
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
      ChartCard(
        title: 'Mwenendo wa Mshahara Safi (Miezi 6)',
        subtitle: 'Jumla ya Net Pay ya kila mwezi (payroll zilizoendeshwa)',
        child: trend.isLoading.value && trend.months.isEmpty
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : trend.error.value.isNotEmpty
                ? EmptyChart(message: trend.error.value)
                : trendHasData
                    ? ColumnChart(items: trendItems, color: Pal.chartBlue)
                    : const EmptyChart(message: 'Hakuna payroll iliyoendeshwa katika miezi 6 iliyopita.'),
      ),
      ChartCard(
        title: 'Hali ya Wafanyakazi',
        subtitle: 'Wafanyakazi ${employees.length} kwa jumla',
        child: DonutChart(
          centerTop: '${employees.length}',
          centerBottom: 'Wafanyakazi',
          valueFormat: (v) => v.toStringAsFixed(0),
          slices: [
            ChartSlice('Hai na wana Hali ya Mshahara', activeWithStatus.toDouble(), const Color(0xFF059669)),
            ChartSlice('Hai bila Hali ya Mshahara', activeNoStatus.toDouble(), const Color(0xFFD97706)),
            ChartSlice('Waliofungiwa', blockedCount.toDouble(), const Color(0xFFDC2626)),
          ],
        ),
      ),
      ChartCard(
        title: 'Wafanyakazi kwa Jinsia',
        child: DonutChart(
          centerTop: '${active.length}',
          centerBottom: 'Walio hai',
          valueFormat: (v) => v.toStringAsFixed(0),
          slices: [for (final e in genderCounts.entries) ChartSlice(e.key, e.value, genderColor(e.key))],
        ),
      ),
      ChartCard(
        title: 'Wafanyakazi kwa Kituo cha Kazi (Top 6)',
        child: BarList(items: _rank(stationCounts, top: 6), valueFormat: (v) => v.toStringAsFixed(0)),
      ),
      ChartCard(
        title: 'Mgawanyo wa Mishahara ya Msingi',
        subtitle: 'Idadi ya wafanyakazi kwa kiwango cha mshahara wa msingi (TZS)',
        child: ColumnChart(items: bandItems, color: const Color(0xFF7C3AED), valueFormat: (v) => v.toStringAsFixed(0)),
      ),
      ChartCard(
        title: 'Posho kwa Aina (mwezi huu)',
        subtitle: sourceNote,
        child: BarList(items: _rank(allowanceTotals)),
      ),
      ChartCard(
        title: 'Makato Mengine kwa Aina (mwezi huu)',
        subtitle: sourceNote,
        child: BarList(items: _rank(arrearTotals)),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TAKWIMU (CHARTS)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Pal.brandText)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final cols = w >= 1250 ? 3 : (w >= 780 ? 2 : 1);
          const gap = 16.0;
          final cardWidth = (w - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final c in cards) SizedBox(width: cardWidth, child: c)],
          );
        }),
      ],
    );
  }

  Widget _payrollStatusCard({
    required NavigationController nav,
    required String monthLabel,
    required bool loading,
    required String error,
    required int processed,
    required int eligible,
    required int withoutStatus,
    required int blocked,
  }) {
    final done = processed > 0;
    final complete = done && eligible > 0 && processed >= eligible;
    final accent = Pal.fg(loading
        ? Colors.grey.shade600
        : error.isNotEmpty
            ? Colors.red.shade700
            : complete
                ? Colors.green.shade700
                : (done ? Colors.amber.shade800 : Colors.orange.shade800));
    final String title = loading
        ? 'Inapakua hali ya payroll ya $monthLabel...'
        : error.isNotEmpty
            ? error
            : done
                ? 'Payroll ya $monthLabel: wafanyakazi $processed kati ya $eligible wameshughulikiwa'
                : 'Payroll ya $monthLabel bado haijaendeshwa';
    final progress = (eligible == 0 || !done) ? 0.0 : (processed / eligible).clamp(0.0, 1.0);

    final alerts = <Widget>[
      if (withoutStatus > 0)
        _alertChip(Icons.warning_amber_rounded, 'Wafanyakazi $withoutStatus hawana Hali ya Mshahara', Colors.orange.shade800,
            () => nav.goTo('salary_status')),
      if (blocked > 0) _alertChip(Icons.block, 'Waliofungiwa: $blocked', Colors.red.shade700, () => nav.goTo('registration')),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(complete ? Icons.verified : Icons.pending_actions, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: accent)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => nav.goTo('run_payroll'),
                icon: const Icon(Icons.play_circle_outline, size: 16),
                label: Text(done ? 'Fungua Payroll' : 'Endesha Payroll',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (!loading && error.isEmpty && eligible > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: progress, minHeight: 7, color: accent, backgroundColor: Pal.surfaceAlt),
            ),
          ],
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: alerts),
          ],
        ],
      ),
    );
  }

  Widget _alertChip(IconData icon, String text, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _banner(NavigationController nav) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _brandBlue, borderRadius: BorderRadius.circular(16)),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        children: [
          const Padding(padding: EdgeInsets.only(right: 18), child: TugheLogo(size: 84, radius: 18)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text('CHAMA CHA WAFANYAKAZI WA SERIKALI NA AFYA TANZANIA',
                      style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                const Text('MFUMO WA TUGHE PAYROLL',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text(
                  'Usajili wa watumishi, usimamizi wa mishahara ya msingi, posho, makato ya arrears, na ukokotoaji rasmi wa kodi ya TRA PAYE.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => nav.goTo('registration'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _brandBlue),
                icon: const Icon(Icons.people_outline, size: 16),
                label: const Text('+ Sajili Mpya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              ElevatedButton.icon(
                onPressed: () => nav.goTo('reports'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade500, foregroundColor: Colors.black),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Sehemu ya Ripoti', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
              ),
              ElevatedButton.icon(
                onPressed: () => nav.goTo('salary_slip'),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Hati za Mshahara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String footer,
    (String, VoidCallback)? footerAction,
    String? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pal.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Pal.textMuted, letterSpacing: 0.5)),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: valueColor)),
              ),
              if (trailing != null)
                Text(trailing, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(footer,
                    overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: Pal.textSecondary)),
              ),
              if (footerAction != null)
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(10, 20)),
                  onPressed: footerAction.$2,
                  child: Text(footerAction.$1,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Pal.brandText)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _employeeTable(List<Employee> employees, List<TRASalaryTerm> traTerms, NavigationController nav) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('ORODHA YA WATUMISHI NA MCHANGANUO WA MSHAHARA',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => nav.goTo('registration'),
                child: Text('Tazama Wote', style: TextStyle(fontSize: 10.5, color: Pal.brandText, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(),
          FullWidthScroll(
            child: DataTable(
              headingRowHeight: 38,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 76,
              dividerThickness: 0.6,
              headingRowColor: WidgetStatePropertyAll(Pal.surfaceAlt),
              columns: const [
                DataColumn(label: Text('Emp ID & Name', style: TextStyle(fontSize: 10))),
                DataColumn(label: Text('Cheo / Kituo', style: TextStyle(fontSize: 10))),
                DataColumn(label: Text('Basic Pay', style: TextStyle(fontSize: 10)), numeric: true),
                DataColumn(label: Text('Posho', style: TextStyle(fontSize: 10)), numeric: true),
                DataColumn(label: Text('PAYE', style: TextStyle(fontSize: 10)), numeric: true),
                DataColumn(label: Text('Net Pay', style: TextStyle(fontSize: 10)), numeric: true),
                DataColumn(label: Text('Action', style: TextStyle(fontSize: 10))),
              ],
              rows: employees.map<DataRow>((emp) {
                final calc = calculateEmployeePayroll(emp, traTerms: traTerms);
                return DataRow(cells: [
                  DataCell(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emp.id, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Pal.brandText)),
                      Text(emp.fullName, style: const TextStyle(fontSize: 10.5)),
                    ],
                  )),
                  DataCell(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emp.salaryStatus?.occupation ?? 'Haijawekwa', style: const TextStyle(fontSize: 10.5)),
                      Text(emp.salaryStatus?.workStation ?? '-',
                          style: TextStyle(fontSize: 9.5, color: Pal.textMuted)),
                    ],
                  )),
                  DataCell(Text(formatTZS(calc.basicSalary), style: const TextStyle(fontSize: 10.5))),
                  DataCell(Text('+${formatTZS(calc.totalAllowances)}',
                      style: TextStyle(fontSize: 10.5, color: Pal.fg(Colors.green.shade700)))),
                  DataCell(Text(formatTZS(calc.traPayeTax),
                      style: TextStyle(fontSize: 10.5, color: Pal.fg(Colors.purple.shade800)))),
                  DataCell(Text(formatTZS(calc.netSalary),
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Pal.brandText))),
                  DataCell(TextButton(
                    onPressed: () {
                      onSelectEmployeeForSlip(emp);
                      nav.goTo('salary_slip');
                    },
                    child: Text('Slip', style: TextStyle(fontSize: 10, color: Pal.brandText, fontWeight: FontWeight.bold)),
                  )),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _traPanel(List<TRASalaryTerm> traTerms, NavigationController nav) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('FOMULA YA KODI YA TRA (PAYE)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => nav.goTo('settings_salary_terms'),
                child: Text('Badili', style: TextStyle(fontSize: 10.5, color: Pal.brandText)),
              ),
            ],
          ),
          const Divider(),
          ...traTerms.map((term) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Pal.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Pal.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Term ${term.termNumber}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Pal.brandText)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Pal.tint(Colors.blue), borderRadius: BorderRadius.circular(20)),
                          child: Text('${term.percentage}%',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Pal.brandText)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kiwango: ${formatTZS(term.minSalary)} - ${term.maxSalary >= 999999999 ? "Zaidi" : formatTZS(term.maxSalary)}',
                      style: const TextStyle(fontSize: 10.5),
                    ),
                    if (term.additionAmount > 0)
                      Text('+ Nyongeza ya Kodi: ${formatTZS(term.additionAmount)}',
                          style: TextStyle(fontSize: 9.5, color: Pal.fg(Colors.purple.shade700), fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Pal.tint(Colors.blue), borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NSSF / PSSSF Contribution', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Pal.brandText)),
                SizedBox(height: 2),
                Text('Kutoa 10% ya Mshahara wa Msingi kabla ya kukokotoa kodi ya PAYE.',
                    style: TextStyle(fontSize: 10, color: Pal.brandText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
