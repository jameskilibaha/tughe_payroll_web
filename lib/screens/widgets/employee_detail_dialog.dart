import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../../controllers/navigation_controller.dart';
import '../../controllers/salary_terms_controller.dart';
import '../../models/employee.dart';
import '../../models/payroll_calculation_result.dart';
import '../../network/api_exception.dart';
import '../../network/api_service.dart';
import '../../utils/formatters.dart';
import '../../utils/payroll_calculator.dart';
import '../../utils/salary_slip_from_generated.dart';
import 'charts.dart';
import 'employee_salary_status_dialog.dart';
import 'employee_arrears_dialog.dart';
import 'employee_allowances_dialog.dart';
import 'full_width_scroll.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';
import '../../core/theme.dart';

// Matches the original EmployeeDetailModal.tsx: blue-900 via blue-800 to
// indigo-900 gradient header with a big rounded avatar box.
const _brandBlue = Color(0xFF1E3A8A);
const _blue800 = Color(0xFF1E40AF);
const _indigo900 = Color(0xFF312E81);

Future<void> showEmployeeDetailDialog(BuildContext context, Employee employee) {
  return showDialog(context: context, builder: (_) => _EmployeeDetailDialog(employee: employee));
}

/// One processed payroll month of this employee.
class _MonthRow {
  _MonthRow(this.monthYear, this.calc);
  final String monthYear; // YYYY-MM
  final PayrollCalculationResult calc;
  int get month => int.parse(monthYear.split('-')[1]);
  String get label => '${shortMonth(month)} ${monthYear.split('-')[0]}';
}

class _EmployeeDetailDialog extends StatefulWidget {
  const _EmployeeDetailDialog({required this.employee});
  final Employee employee;

  @override
  State<_EmployeeDetailDialog> createState() => _EmployeeDetailDialogState();
}

class _EmployeeDetailDialogState extends State<_EmployeeDetailDialog> {
  List<_MonthRow>? _history; // null = loading
  String? _error;
  int _seq = 0;

  Employee get employee => widget.employee;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = employee.backendId;
    if (id == null) {
      setState(() => _history = []);
      return;
    }
    final seq = ++_seq;
    setState(() {
      _history = null;
      _error = null;
    });
    try {
      final rows = await Get.find<ApiService>().searchSalarySlipHistory(employeeId: id, months: 12);
      if (!mounted || seq != _seq) return;
      final byMonth = <String, List<Map<String, dynamic>>>{};
      for (final raw in rows) {
        final m = Map<String, dynamic>.from(raw as Map);
        final key = m['geneMonthYear'] as String? ?? '';
        if (key.isEmpty) continue;
        byMonth.putIfAbsent(key, () => []).add(m);
      }
      final keys = byMonth.keys.toList()..sort();
      setState(() => _history = [for (final k in keys) _MonthRow(k, buildResultFromGeneratedRows(employee, byMonth[k]!))]);
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _history = [];
        _error = e is ApiException ? e.message : 'Imeshindwa kupakua historia ya payroll ya mfanyakazi huyu.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBlocked = employee.status == 'Blocked';
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: math.min(1040, size.width - 32),
        height: math.min(780, size.height - 32),
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              _header(context, isBlocked),
              Container(
                color: Pal.surface,
                child: TabBar(
                  labelColor: Pal.brandText,
                  indicatorColor: Pal.brandText,
                  unselectedLabelColor: Colors.black45,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(icon: const Icon(Icons.dashboard_outlined, size: 17), text: tr('Dashboard Yake')),
                    Tab(icon: const Icon(Icons.history, size: 17), text: tr('Historia ya Payroll')),
                    Tab(icon: const Icon(Icons.badge_outlined, size: 17), text: tr('Taarifa Zote')),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [_dashboardTab(), _historyTab(), _allInfoTab()],
                ),
              ),
              const Divider(height: 1),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // header / footer
  // ---------------------------------------------------------------------

  Widget _header(BuildContext context, bool isBlocked) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_brandBlue, _blue800, _indigo900]),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Pal.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200, width: 2),
            ),
            child: Text(
              '${employee.firstName.isNotEmpty ? employee.firstName[0] : ''}${employee.lastName.isNotEmpty ? employee.lastName[0] : ''}',
              style: TextStyle(color: Pal.brandText, fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Row(children: [
                  Text(employee.id, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isBlocked ? Colors.red.shade600 : Colors.green.shade600,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(isBlocked ? 'BLOCKED' : 'ACTIVE',
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  if (employee.salaryStatus != null) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text('${employee.salaryStatus!.occupation} • ${employee.salaryStatus!.workStation}',
                          style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 20, color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              showSalaryStatusDialog(context, employee);
            },
            child: const Text('Hali ya Mshahara'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              showArrearsDialog(context, employee);
            },
            child: const Text('Makato'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              showAllowancesDialog(context, employee);
            },
            child: const Text('Posho'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Get.find<NavigationController>().goToPayslip(employee);
            },
            child: const Text('Nenda Salary Slip'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // shared pieces
  // ---------------------------------------------------------------------

  /// Latest processed month, or an estimate when this employee has no payroll yet.
  PayrollCalculationResult _latestOrEstimate(List<_MonthRow> h) {
    if (h.isNotEmpty) return h.last.calc;
    return calculateEmployeePayroll(employee, traTerms: Get.find<SalaryTermsController>().traTerms.toList());
  }

  Widget _loadingOrError() {
    if (_history == null) {
      return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_error != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Pal.tint(Colors.red), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.error_outline, size: 15, color: Pal.fg(Colors.red.shade800)),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: TextStyle(fontSize: 11, color: Pal.fg(Colors.red.shade900), fontWeight: FontWeight.bold))),
          TextButton(onPressed: _load, child: const Text('Jaribu Tena', style: TextStyle(fontSize: 11))),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _kpi(String label, String value, IconData icon, Color color, {String? note}) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Pal.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 9.5, color: Pal.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                if (note != null) Text(note, style: TextStyle(fontSize: 9, color: Pal.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // TAB 1: personal dashboard
  // ---------------------------------------------------------------------

  Widget _dashboardTab() {
    final h = _history ?? const <_MonthRow>[];
    final hasHistory = h.isNotEmpty;
    final latest = _latestOrEstimate(h);
    final sourceNote = hasHistory ? 'Payroll halisi ya ${h.last.label}' : 'Makadirio (bado hajafanyiwa payroll)';

    final totalNet = h.fold<double>(0, (s, m) => s + m.calc.netSalary);
    final totalPaye = h.fold<double>(0, (s, m) => s + m.calc.traPayeTax);
    final totalNssf = h.fold<double>(0, (s, m) => s + m.calc.nssfDeduction);
    final avgNet = hasHistory ? totalNet / h.length : 0.0;

    final dob = DateTime.tryParse(employee.dateOfBirth);
    final doe = DateTime.tryParse(employee.dateOfEmployment);
    final retIso = computeRetirementDateIso(employee.dateOfBirth);
    final ret = retIso == null ? null : DateTime.tryParse(retIso);
    final now = DateTime.now();
    final int? serviceMonths = doe == null ? null : math.max(0, (now.year - doe.year) * 12 + now.month - doe.month);
    final sm = serviceMonths ?? 0;
    final yearsLeft = ret == null ? null : math.max(0, ret.year - now.year);

    // allowances / deductions of the latest (or estimated) payroll
    final allowanceItems = <String, double>{for (final a in latest.allowanceDetails) a.name: a.amount};
    final deductionItems = <String, double>{
      'NSSF': latest.nssfDeduction,
      'TRA PAYE': latest.traPayeTax,
      for (final a in latest.arrearsDetails) a.name: a.amount,
    };
    List<ChartSlice> ranked(Map<String, double> m, {int top = 6}) {
      final colors = [Pal.chartBlue, Color(0xFF7C3AED), Color(0xFF059669), Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF0891B2), Color(0xFFDB2777)];
      final e = m.entries.where((x) => x.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
      return [for (var i = 0; i < e.length && i < top; i++) ChartSlice(e[i].key, e[i].value, colors[i % colors.length])];
    }

    final debts = (employee.arrearsList ?? const []).where((a) => a.isDebtReduction && (a.remainingDebtAmount ?? 0) > 0).toList();

    final summary = <String>[
      if (doe != null) 'Ameajiriwa tarehe ${formatDate(employee.dateOfEmployment)} (miaka ${sm ~/ 12} na miezi ${sm % 12} ya utumishi).',
      if (ret != null) 'Anatarajiwa kustaafu tarehe ${formatDate(retIso!)} (zimebaki takriban miaka $yearsLeft).',
      if (employee.salaryStatus != null)
        'Wadhifa: ${employee.salaryStatus!.occupation}, kituo: ${employee.salaryStatus!.workStation}, mshahara wa msingi ${formatTZS(employee.salaryStatus!.basicSalary)}, benki: ${employee.salaryStatus!.bankName}.'
      else
        'Bado hana Hali ya Mshahara (hawezi kulipwa hadi iwekwe).',
      if (hasHistory) 'Amefanyiwa payroll miezi ${h.length} (kutoka ${h.first.label} hadi ${h.last.label}).' else 'Bado hajafanyiwa payroll yoyote.',
      if (hasHistory) 'Net Pay ya ${h.last.label}: ${formatTZS(h.last.calc.netSalary)} (Ghafi ${formatTZS(h.last.calc.grossSalary)}).',
      if (hasHistory) 'Wastani wa Net Pay: ${formatTZS(avgNet)}; jumla ya Net aliyolipwa: ${formatTZS(totalNet)}.',
      if (hasHistory) 'Jumla ya PAYE: ${formatTZS(totalPaye)}; jumla ya NSSF (mchango wake): ${formatTZS(totalNssf)}.',
      'Posho zinazotumika: ${(employee.allowancesList ?? const []).length}${(employee.allowancesList ?? const []).isEmpty ? '' : ' (${(employee.allowancesList ?? const []).map((a) => a.name).join(', ')})'}.',
      'Makato yanayotumika: ${(employee.arrearsList ?? const []).length}${(employee.arrearsList ?? const []).isEmpty ? '' : ' (${(employee.arrearsList ?? const []).map((a) => a.name).join(', ')})'}.',
      if (debts.isNotEmpty) 'Deni lililobaki: ${formatTZS(debts.fold<double>(0, (s, a) => s + (a.remainingDebtAmount ?? 0)))}.',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _loadingOrError(),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _kpi('Mshahara wa Msingi', formatTZS(employee.salaryStatus?.basicSalary ?? 0), Icons.payments_outlined, _brandBlue),
            _kpi('Net Pay (${hasHistory ? h.last.label : 'makadirio'})', formatTZS(latest.netSalary), Icons.account_balance_wallet_outlined,
                Colors.green.shade700),
            _kpi('Wastani wa Net', hasHistory ? formatTZS(avgNet) : '-', Icons.trending_up, const Color(0xFF7C3AED)),
            _kpi('Payroll Zilizoendeshwa', '${h.length}', Icons.fact_check_outlined, Colors.amber.shade800, note: 'miezi ya mwisho 12'),
            _kpi('Muda wa Utumishi', serviceMonths == null ? '-' : '${sm ~/ 12} miaka ${sm % 12} mwezi', Icons.work_history_outlined,
                const Color(0xFF0891B2)),
            _kpi('Kustaafu', ret == null ? '-' : formatDate(retIso!), Icons.event_available_outlined, Colors.blueGrey.shade700,
                note: yearsLeft == null ? null : 'miaka $yearsLeft iliyobaki'),
          ]),
          const SizedBox(height: 16),
          ChartCard(
            title: 'Ndondoo za Taarifa Zake',
            subtitle: 'Muhtasari wa taarifa zake zote kwenye mfumo',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in summary)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: EdgeInsets.only(top: 5, right: 8), child: Icon(Icons.circle, size: 6, color: Pal.brandText)),
                        Expanded(child: Text(line, style: const TextStyle(fontSize: 11.5))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 760 ? 2 : 1;
            const gap = 14.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            final monthItems = [for (final m in h) ColumnItem(m.label, m.calc.netSalary, tooltip: '${m.label}\nNet: ${formatTZS(m.calc.netSalary)}\nGhafi: ${formatTZS(m.calc.grossSalary)}')];
            final payeItems = [for (final m in h) ColumnItem(m.label, m.calc.traPayeTax + m.calc.nssfDeduction, tooltip: '${m.label}\nPAYE: ${formatTZS(m.calc.traPayeTax)}\nNSSF: ${formatTZS(m.calc.nssfDeduction)}')];
            final cards = <Widget>[
              ChartCard(
                title: 'Mgawanyo wa Mshahara Ghafi',
                subtitle: sourceNote,
                child: DonutChart(
                  centerTop: formatAmount(latest.grossSalary),
                  centerBottom: 'Ghafi',
                  slices: [
                    ChartSlice('Mshahara Safi (Net)', latest.netSalary, const Color(0xFF059669)),
                    ChartSlice('Kodi ya TRA (PAYE)', latest.traPayeTax, const Color(0xFF7C3AED)),
                    ChartSlice('NSSF', latest.nssfDeduction, Pal.chartBlue),
                    ChartSlice('Makato Mengine', latest.totalOtherDeductions, const Color(0xFFD97706)),
                  ],
                ),
              ),
              ChartCard(
                title: 'Mwenendo wa Net Pay (Miezi ${math.max(h.length, 1)})',
                subtitle: 'Net Pay ya kila mwezi aliofanyiwa payroll',
                child: hasHistory ? ColumnChart(items: monthItems, color: Pal.chartBlue) : const EmptyChart(message: 'Bado hajafanyiwa payroll yoyote.'),
              ),
              ChartCard(
                title: 'Posho Zake',
                subtitle: sourceNote,
                child: BarList(items: ranked(allowanceItems)),
              ),
              ChartCard(
                title: 'Makato Yake',
                subtitle: sourceNote,
                child: BarList(items: ranked(deductionItems)),
              ),
              ChartCard(
                title: 'PAYE na NSSF kwa Mwezi',
                subtitle: 'Kodi + mchango wa NSSF kila mwezi',
                child: hasHistory ? ColumnChart(items: payeItems, color: const Color(0xFF7C3AED)) : const EmptyChart(message: 'Bado hajafanyiwa payroll yoyote.'),
              ),
              if (debts.isNotEmpty)
                ChartCard(
                  title: 'Madeni Yaliyobaki',
                  child: BarList(items: [for (final d in debts) ChartSlice(d.name, d.remainingDebtAmount ?? 0, const Color(0xFFDC2626))]),
                ),
            ];
            return Wrap(spacing: gap, runSpacing: gap, children: [for (final c in cards) SizedBox(width: w, child: c)]);
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // TAB 2: payroll history
  // ---------------------------------------------------------------------

  Widget _historyTab() {
    final h = (_history ?? const <_MonthRow>[]).reversed.toList(); // newest first
    double sum(double Function(PayrollCalculationResult) f) => h.fold<double>(0, (s, m) => s + f(m.calc));
    Text c(String t, {bool bold = false, Color? color}) =>
        Text(t, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _loadingOrError(),
          if (_history != null && h.isEmpty && _error == null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('Bado hajafanyiwa payroll yoyote.', style: TextStyle(color: Pal.textMuted))),
            ),
          if (h.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Pal.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Pal.border),
              ),
              child: FullWidthScroll(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Pal.surfaceAlt),
                  headingRowHeight: 38,
                  dataRowMinHeight: 38,
                  dataRowMaxHeight: 44,
                  columns: const [
                    DataColumn(label: Text('Mwezi')),
                    DataColumn(label: Text('Basic Pay'), numeric: true),
                    DataColumn(label: Text('Posho'), numeric: true),
                    DataColumn(label: Text('Mshahara Ghafu'), numeric: true),
                    DataColumn(label: Text('Makato ya NSSF'), numeric: true),
                    DataColumn(label: Text('Kodi ya TRA'), numeric: true),
                    DataColumn(label: Text('Makato Mengine'), numeric: true),
                    DataColumn(label: Text('Mshahara Safi (Net)'), numeric: true),
                  ],
                  rows: [
                    for (final m in h)
                      DataRow(cells: [
                        DataCell(c(m.label, bold: true)),
                        DataCell(c(formatTZS(m.calc.basicSalary))),
                        DataCell(c('+${formatTZS(m.calc.totalAllowances)}', color: Pal.fg(Colors.green.shade700))),
                        DataCell(c(formatTZS(m.calc.grossSalary))),
                        DataCell(c(formatTZS(m.calc.nssfDeduction), color: Pal.fg(Colors.blue.shade700))),
                        DataCell(c(formatTZS(m.calc.traPayeTax), color: Pal.fg(Colors.purple.shade800))),
                        DataCell(c(formatTZS(m.calc.totalOtherDeductions), color: Pal.fg(Colors.orange.shade800))),
                        DataCell(c(formatTZS(m.calc.netSalary), bold: true, color: Pal.brandText)),
                      ]),
                    DataRow(color: WidgetStateProperty.all(const Color(0xFF0F172A)), cells: [
                      DataCell(c('JUMLA', bold: true, color: Colors.amber.shade400)),
                      DataCell(c(formatTZS(sum((x) => x.basicSalary)), bold: true, color: Colors.white)),
                      DataCell(c(formatTZS(sum((x) => x.totalAllowances)), bold: true, color: Colors.white)),
                      DataCell(c(formatTZS(sum((x) => x.grossSalary)), bold: true, color: Colors.white)),
                      DataCell(c(formatTZS(sum((x) => x.nssfDeduction)), bold: true, color: Colors.white)),
                      DataCell(c(formatTZS(sum((x) => x.traPayeTax)), bold: true, color: Colors.white)),
                      DataCell(c(formatTZS(sum((x) => x.totalOtherDeductions)), bold: true, color: Colors.white)),
                      DataCell(c(formatTZS(sum((x) => x.netSalary)), bold: true, color: Colors.amber.shade400)),
                    ]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // TAB 3: everything we hold about this employee
  // ---------------------------------------------------------------------

  Widget _allInfoTab() {
    final allowances = employee.allowancesList ?? const [];
    final arrears = employee.arrearsList ?? const [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Taarifa Binafsi'),
          _kv('Jinsia', employee.gender),
          _kv('Hali ya Ndoa', employee.maritalStatus),
          _kv('Uraia', employee.nationality),
          _kv('Wilaya', employee.residentialDistrict),
          _kv('Simu', employee.mobileNumber),
          _kv('Barua Pepe', employee.email),
          _kv('Tarehe ya Kuzaliwa', formatDate(employee.dateOfBirth)),
          _kv('Tarehe ya Kuajiriwa', formatDate(employee.dateOfEmployment)),
          const SizedBox(height: 12),
          _sectionTitle('Hali ya Mshahara'),
          if (employee.salaryStatus != null) ...[
            _kv('Wadhifa', employee.salaryStatus!.occupation),
            _kv('Kituo', employee.salaryStatus!.workStation),
            _kv('Mshahara wa Msingi', formatTZS(employee.salaryStatus!.basicSalary)),
            _kv('Benki', '${employee.salaryStatus!.bankName} (${employee.salaryStatus!.bankAccountNumber})'),
          ] else
            Text('Bado hazijawekwa.', style: TextStyle(color: Pal.textMuted, fontSize: 11.5)),
          const SizedBox(height: 12),
          _sectionTitle('Posho Alizopewa (${allowances.length})'),
          if (allowances.isEmpty)
            Text('Hakuna posho zilizowekwa bado.', style: TextStyle(color: Pal.textMuted, fontSize: 11.5))
          else
            for (final a in allowances)
              _kv(a.name, '${a.additionType == 'Percent' ? '${a.value}% ya mshahara wa msingi' : formatTZS(a.value)}${a.isSpecial ? '  •  Special' : ''}'),
          const SizedBox(height: 12),
          _sectionTitle('Makato Aliyopewa (${arrears.length})'),
          if (arrears.isEmpty)
            Text('Hakuna makato yaliyowekwa bado.', style: TextStyle(color: Pal.textMuted, fontSize: 11.5))
          else
            for (final a in arrears)
              _kv(
                a.name,
                '${a.deductionType == 'Percent' ? '${a.value}% ya mshahara wa msingi' : formatTZS(a.value)}  •  ${a.frequency}'
                '${a.isDebtReduction && a.remainingDebtAmount != null ? '  •  Deni lililobaki: ${formatTZS(a.remainingDebtAmount!)}' : ''}',
              ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Pal.brandText)),
      );

  Widget _kv(String key, String value, {bool emphasize = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 180, child: Text(key, style: TextStyle(fontSize: 11.5, color: Pal.textSecondary))),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: emphasize ? FontWeight.w900 : FontWeight.w600,
                      color: emphasize ? Pal.brandText : Pal.text)),
            ),
          ],
        ),
      );
}
