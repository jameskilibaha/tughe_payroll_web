import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/salary_terms_controller.dart';
import '../models/employee.dart';
import '../models/payroll_calculation_result.dart';
import '../utils/csv_export_web.dart';
import '../utils/formatters.dart';
import '../utils/payroll_calculator.dart';
import 'widgets/responsive_header_bar.dart';

const _brandBlue = Color(0xFF1E3A8A);
const _slate900 = Color(0xFF0F172A);
const _amber400 = Color(0xFFFBBF24);

enum ReportTab { masterPayroll, traPaye, nssfPension, bankSchedule, deductionsArrears }

const List<String> _swahiliMonths = [
  'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni',
  'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba',
];

const List<String> _knownBanks = ['ALL', 'NMB Bank', 'CRDB Bank', 'NBC Bank', 'Stanbic Bank'];

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.onNavigateToSalarySlip});

  final VoidCallback? onNavigateToSalarySlip;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportTab _activeTab = ReportTab.masterPayroll;
  String _searchTerm = '';
  String _selectedBank = 'ALL';

  late int _selectedMonthIndex = DateTime.now().month - 1;
  late int _selectedYear = DateTime.now().year;

  String get _selectedMonthLabel => '${_swahiliMonths[_selectedMonthIndex]} $_selectedYear';

  @override
  Widget build(BuildContext context) {
    final employeeCtrl = Get.find<EmployeeController>();
    final termsCtrl = Get.find<SalaryTermsController>();

    return Obx(() {
      final traTerms = termsCtrl.traTerms.toList();
      final activeEmployees = employeeCtrl.employees.where((e) => e.status == 'Active').toList();

      final payrollCalculations = activeEmployees
          .map((e) => (employee: e, calc: calculateEmployeePayroll(e, traTerms: traTerms)))
          .toList();

      final filtered = payrollCalculations.where((r) {
        final q = _searchTerm.toLowerCase();
        final matchesSearch = q.isEmpty ||
            r.employee.id.toLowerCase().contains(q) ||
            r.calc.employeeName.toLowerCase().contains(q);
        final bankName = r.employee.salaryStatus?.bankName ?? 'NMB Bank';
        final matchesBank = _selectedBank == 'ALL' || bankName.toUpperCase() == _selectedBank.toUpperCase();
        return matchesSearch && matchesBank;
      }).toList();

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
            const SizedBox(height: 16),
            _summaryCards(filtered.length, gross, tra, nssf, totalDeductions, net),
            const SizedBox(height: 16),
            _reportTabsBar(),
            const SizedBox(height: 16),
            _filterBar(),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SEHEMU YA RIPOTI ZA MSHAHARA NA KODI',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _slate900)),
                  SizedBox(height: 2),
                  Text('Tengeneza, pakua CSV/Excel, na uchapishe ripoti rasmi za TUGHE, TRA, NSSF na Benki.',
                      style: TextStyle(fontSize: 11, color: Colors.black54)),
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
              decoration: const InputDecoration(isDense: true, labelText: 'Kipindi'),
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
              decoration: const InputDecoration(isDense: true, labelText: 'Mwaka'),
              items: List.generate(3, (i) => DateTime.now().year - i)
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
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kuchapisha kunahitaji kiendeshi cha PDF/printer kilichowekwa.')),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Chapisha (Print)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Summary cards
  // ---------------------------------------------------------------------

  Widget _summaryCards(int count, double gross, double tra, double nssf, double totalDeductions, double net) {
    final cards = [
      _statCard('WAFANYAKAZI', count.toString(), _slate900),
      _statCard('MSHAHARA GHAFU', formatTZS(gross), _brandBlue),
      _statCard('TRA PAYE TAX', formatTZS(tra), Colors.amber.shade800),
      _statCard('NSSF (10%)', formatTZS(nssf), Colors.blue.shade700),
      _statCard('JUMLA MAKATO', formatTZS(totalDeductions), Colors.red.shade700),
      _statCard('MSHAHARA SAFI (NET)', formatTZS(net), Colors.white, dark: true),
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

  Widget _statCard(String label, String value, Color valueColor, {bool dark = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? Colors.green.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: dark ? null : Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800, color: dark ? Colors.greenAccent.shade100 : Colors.black38)),
          const SizedBox(height: 4),
          Text(value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: valueColor)),
        ],
      ),
    );
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              decoration: const InputDecoration(
                  isDense: true, prefixIcon: Icon(Icons.search, size: 16), hintText: 'Tafuta kwa PF ID au Jina...'),
              onChanged: (v) => setState(() => _searchTerm = v),
            ),
          ),
          if (_activeTab == ReportTab.bankSchedule)
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                value: _selectedBank,
                decoration: const InputDecoration(isDense: true, labelText: 'Filter kwa Benki'),
                items: _knownBanks
                    .map((b) => DropdownMenuItem(
                        value: b, child: Text(b == 'ALL' ? 'Benki Zote' : b, style: const TextStyle(fontSize: 11.5))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedBank = v ?? 'ALL'),
              ),
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
          const DataColumn(label: Text('NSSF 10%'), numeric: true),
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
          const DataColumn(label: Text('Mchango Mfanyakazi (10%)'), numeric: true),
          const DataColumn(label: Text('Mchango Mwajiri (10%)'), numeric: true),
          const DataColumn(label: Text('Jumla Mchango (20%)'), numeric: true),
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
          const DataColumn(label: Text('NSSF (10%)'), numeric: true),
          const DataColumn(label: Text('TRA PAYE'), numeric: true),
          const DataColumn(label: Text('Madeni & Arrears'), numeric: true),
          const DataColumn(label: Text('Jumla Makato'), numeric: true),
        ];
    }
  }

  DataRow _row(Employee employee, PayrollCalculationResult calc) {
    Widget cell(String text, {Color? color, bool bold = false}) => Text(text,
        style: TextStyle(fontSize: 11, color: color ?? Colors.black87, fontWeight: bold ? FontWeight.bold : null));

    final baseCells = [
      DataCell(Text(employee.id, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brandBlue))),
      DataCell(Text(calc.employeeName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
    ];

    switch (_activeTab) {
      case ReportTab.masterPayroll:
        final otherDeductions = calc.totalDeductions - (calc.nssfDeduction + calc.traPayeTax);
        return DataRow(cells: [
          ...baseCells,
          DataCell(cell(employee.salaryStatus?.workStation ?? 'Makao Makuu')),
          DataCell(cell(formatTZS(calc.basicSalary))),
          DataCell(cell(formatTZS(calc.grossSalary), color: _brandBlue, bold: true)),
          DataCell(cell(formatTZS(calc.nssfDeduction), color: Colors.blue.shade700)),
          DataCell(cell(formatTZS(calc.traPayeTax), color: Colors.amber.shade800)),
          DataCell(cell(formatTZS(otherDeductions))),
          DataCell(cell(formatTZS(calc.totalDeductions), color: Colors.red.shade700, bold: true)),
          DataCell(cell(formatTZS(calc.netSalary), color: Colors.green.shade700, bold: true)),
        ]);
      case ReportTab.traPaye:
        return DataRow(cells: [
          ...baseCells,
          DataCell(cell(employee.salaryStatus?.occupation ?? '-')),
          DataCell(cell(formatTZS(calc.grossSalary))),
          DataCell(cell(formatTZS(calc.nssfDeduction), color: Colors.blue.shade700)),
          DataCell(cell(formatTZS(calc.grossSalary - calc.nssfDeduction))),
          DataCell(cell(formatTZS(calc.traPayeTax), color: Colors.amber.shade800, bold: true)),
        ]);
      case ReportTab.nssfPension:
        return DataRow(cells: [
          ...baseCells,
          DataCell(cell(formatTZS(calc.grossSalary))),
          DataCell(cell(formatTZS(calc.nssfDeduction), color: Colors.blue.shade700, bold: true)),
          DataCell(cell(formatTZS(calc.nssfDeduction))),
          DataCell(cell(formatTZS(calc.nssfDeduction * 2), color: _brandBlue, bold: true)),
        ]);
      case ReportTab.bankSchedule:
        return DataRow(cells: [
          ...baseCells,
          DataCell(cell(employee.salaryStatus?.bankName ?? 'NMB Bank', bold: true)),
          DataCell(Text(employee.salaryStatus?.bankAccountNumber ?? '-',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
          DataCell(cell(formatTZS(calc.netSalary), color: Colors.green.shade700, bold: true)),
        ]);
      case ReportTab.deductionsArrears:
        final otherDeductions = calc.totalDeductions - (calc.nssfDeduction + calc.traPayeTax);
        return DataRow(cells: [
          ...baseCells,
          DataCell(cell(formatTZS(calc.nssfDeduction), color: Colors.blue.shade700)),
          DataCell(cell(formatTZS(calc.traPayeTax), color: Colors.amber.shade800)),
          DataCell(cell(formatTZS(otherDeductions))),
          DataCell(cell(formatTZS(calc.totalDeductions), color: Colors.red.shade700, bold: true)),
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
          DataCell(t(formatTZS(gross - nssf))),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: _slate900,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TANZANIA UNION OF GOVERNMENT AND HEALTH EMPLOYEES (TUGHE)',
                          style: TextStyle(color: _amber400, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('$_tabTitle - ${_selectedMonthLabel.toUpperCase()}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(4)),
                  child: Text('Jumla: ${filtered.length} Records',
                      style: TextStyle(color: Colors.blue.shade200, fontSize: 10, fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
          filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Hakuna Rekodi Zinazolingana.', style: TextStyle(color: Colors.black45))),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                    columns: _columns,
                    rows: [
                      for (final r in filtered) _row(r.employee, r.calc),
                      _totalsRow(basic, gross, nssf, tra, totalDeductions, net),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // CSV export per active tab
  // ---------------------------------------------------------------------

  void _exportCurrentTabCsv() {
    final employeeCtrl = Get.find<EmployeeController>();
    final termsCtrl = Get.find<SalaryTermsController>();
    final traTerms = termsCtrl.traTerms.toList();
    final activeEmployees = employeeCtrl.employees.where((e) => e.status == 'Active').toList();
    final rowsData = activeEmployees
        .map((e) => (employee: e, calc: calculateEmployeePayroll(e, traTerms: traTerms)))
        .where((r) {
      final q = _searchTerm.toLowerCase();
      final matchesSearch = q.isEmpty ||
          r.employee.id.toLowerCase().contains(q) ||
          r.calc.employeeName.toLowerCase().contains(q);
      final bankName = r.employee.salaryStatus?.bankName ?? 'NMB Bank';
      final matchesBank = _selectedBank == 'ALL' || bankName.toUpperCase() == _selectedBank.toUpperCase();
      return matchesSearch && matchesBank;
    }).toList();

    final monthTag = _selectedMonthLabel.replaceAll(' ', '_');
    List<String> headers;
    List<List<Object?>> rows;
    String filenamePrefix;

    switch (_activeTab) {
      case ReportTab.masterPayroll:
        filenamePrefix = 'Master_Payroll_Report';
        headers = const [
          'PF ID', 'Jina Kamili', 'Cheo', 'Kituo cha Kazi', 'Mshahara wa Msingi (Basic)',
          'Posho (Allowances)', 'Mshahara Ghafu (Gross)', 'NSSF (10%)', 'TRA PAYE Tax',
          'Makato Mengine (Arrears)', 'Jumla ya Makato', 'Mshahara Safi (Net Pay)',
        ];
        rows = rowsData
            .map((r) => [
                  r.employee.id,
                  r.calc.employeeName,
                  r.employee.salaryStatus?.occupation ?? '-',
                  r.employee.salaryStatus?.workStation ?? '-',
                  r.calc.basicSalary,
                  r.calc.grossSalary - r.calc.basicSalary,
                  r.calc.grossSalary,
                  r.calc.nssfDeduction,
                  r.calc.traPayeTax,
                  r.calc.totalDeductions - (r.calc.nssfDeduction + r.calc.traPayeTax),
                  r.calc.totalDeductions,
                  r.calc.netSalary,
                ])
            .toList();
        break;
      case ReportTab.traPaye:
        filenamePrefix = 'TRA_PAYE_Tax_Report';
        headers = const ['PF ID', 'Jina Kamili', 'Kiasi Kinachokatwa Kodi', 'Kodi ya TRA (PAYE)', 'Hali ya Mfanyakazi'];
        rows = rowsData
            .map((r) => [
                  r.employee.id,
                  r.calc.employeeName,
                  r.calc.grossSalary - r.calc.nssfDeduction,
                  r.calc.traPayeTax,
                  r.employee.status,
                ])
            .toList();
        break;
      case ReportTab.nssfPension:
        filenamePrefix = 'NSSF_PSSSF_Pension_Report';
        headers = const [
          'PF ID', 'Jina Kamili', 'Mshahara Ghafu', 'Mchango wa Mfanyakazi (10%)',
          'Mchango wa Mwajiri (10%)', 'Jumla ya Mfuko (20%)',
        ];
        rows = rowsData
            .map((r) => [
                  r.employee.id,
                  r.calc.employeeName,
                  r.calc.grossSalary,
                  r.calc.nssfDeduction,
                  r.calc.nssfDeduction,
                  r.calc.nssfDeduction * 2,
                ])
            .toList();
        break;
      case ReportTab.bankSchedule:
        filenamePrefix = 'Bank_Paylist_Schedule';
        headers = const ['PF ID', 'Jina la Mfanyakazi', 'Jina la Benki', 'Namba ya Akaunti', 'Mshahara Safi (Net Pay)'];
        rows = rowsData
            .map((r) => [
                  r.employee.id,
                  r.calc.employeeName,
                  r.employee.salaryStatus?.bankName ?? 'NMB Bank',
                  r.employee.salaryStatus?.bankAccountNumber ?? '-',
                  r.calc.netSalary,
                ])
            .toList();
        break;
      case ReportTab.deductionsArrears:
        filenamePrefix = 'Deductions_Arrears_Report';
        headers = const [
          'PF ID', 'Jina Kamili', 'Makato ya NSSF', 'Makato ya TRA PAYE', 'Madeni & Arrears', 'Jumla ya Makato',
        ];
        rows = rowsData
            .map((r) => [
                  r.employee.id,
                  r.calc.employeeName,
                  r.calc.nssfDeduction,
                  r.calc.traPayeTax,
                  r.calc.totalDeductions - (r.calc.nssfDeduction + r.calc.traPayeTax),
                  r.calc.totalDeductions,
                ])
            .toList();
        break;
    }

    downloadCsv(filename: '${filenamePrefix}_$monthTag.csv', headers: headers, rows: rows);
  }
}
