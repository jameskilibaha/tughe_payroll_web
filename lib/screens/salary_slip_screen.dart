import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../controllers/employee_controller.dart';
import '../controllers/month_payroll_controller.dart';
import '../controllers/salary_terms_controller.dart';
import '../models/employee.dart';
import '../models/payroll_calculation_result.dart';
import '../network/api_exception.dart';
import '../network/api_service.dart';
import '../utils/csv_export_web.dart';
import '../utils/formatters.dart';
import '../utils/payroll_calculator.dart';
import '../utils/salary_slip_from_generated.dart';
import 'package:printing/printing.dart';
import '../utils/salary_slip_pdf.dart';
import 'widgets/responsive_header_bar.dart';
import 'widgets/tughe_logo.dart';
import '../core/tr_snack.dart';
import '../core/tr_text.dart';
import '../core/translations.dart';
import '../core/theme.dart';

const _brandBlue = Color(0xFF1E3A8A);
const _emerald800 = Color(0xFF065F46);
const _red800 = Color(0xFF991B1B);

/// Mwezi + Mwaka options for the salary slip period selector, mirroring the
/// <select> in the original SalarySlipView.tsx.
const List<String> _swahiliMonths = [
  'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni',
  'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba',
];

class SalarySlipScreen extends StatefulWidget {
  const SalarySlipScreen({super.key, this.initialEmployee});

  final Employee? initialEmployee;

  @override
  State<SalarySlipScreen> createState() => _SalarySlipScreenState();
}

class _SalarySlipScreenState extends State<SalarySlipScreen> {
  Employee? _selected;
  String _employeeSearch = '';

  // Defaults to the current month/year, matching the "latest payroll period"
  // behaviour of the original component.
  late int _selectedMonthIndex = DateTime.now().month - 1;
  late int _selectedYear = DateTime.now().year;

  /// Real generated payroll rows for the current employee/period, if any
  /// (see tughe/payroll/service.py: PROCESSING()). Null/empty means
  /// payroll hasn't been run for this employee/period yet - the screen
  /// then falls back to a live, unofficial estimate.
  List<Map<String, dynamic>>? _generatedRows;
  bool _loadingGenerated = false;
  String? _fetchedFor;

  String get _selectedMonthLabel =>
      '${_swahiliMonths[_selectedMonthIndex]} $_selectedYear (Mwezi wa ${_selectedMonthIndex + 1})';

  String get _monthYearKey => '$_selectedYear-${(_selectedMonthIndex + 1).toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _selected = widget.initialEmployee;
    _maybeFetchGenerated(_selected);
  }

  /// Incremented on every fetch so that a slow response for a previous
  /// month/employee can never overwrite the data of the one now selected.
  int _fetchSeq = 0;
  String? _fetchError;
  Employee? _currentForRetry;

  /// The PDF payslip made by the server: [style] 'simple' (short, classic) or 'full' (every detail).
  Future<void> _downloadServerPdf(Employee emp, String style) async {
    final id = emp.backendId;
    if (id == null) return;
    try {
      final bytes = await Get.find<ApiService>().salarySlipPdf(employeeId: id, monthYear: _monthYearKey, style: style);
      final safe = emp.fullName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      saveBytesAs(
        filename: 'Salary_Slip_${safe}_${_monthYearKey}_${style == 'simple' ? 'Simple' : 'Full'}.pdf',
        bytes: Uint8List.fromList(bytes),
        mime: 'application/pdf',
      );
    } catch (e) {
      trSnack('Imeshindikana', e is ApiException ? e.message : 'Imeshindwa kupakua PDF ya payslip.');
    }
  }

  /// Prints the SAME PDF the server makes (Simple or Full) - what you see in the sample is what is printed.
  Future<void> _printServerPdf(Employee emp, String style) async {
    final id = emp.backendId;
    if (id == null) return;
    try {
      final bytes = await Get.find<ApiService>().salarySlipPdf(employeeId: id, monthYear: _monthYearKey, style: style);
      final data = Uint8List.fromList(bytes);
      await Printing.layoutPdf(
        name: 'Salary_Slip_${_monthYearKey}_${style == 'simple' ? 'Simple' : 'Full'}',
        onLayout: (_) async => data,
      );
    } catch (e) {
      trSnack('Imeshindikana', e is ApiException ? e.message : 'Imeshindwa kuchapisha payslip.');
    }
  }

  Future<void> _maybeFetchGenerated(Employee? emp, {bool force = false}) async {
    if (emp?.backendId == null) {
      if (mounted) setState(() => _generatedRows = null);
      return;
    }
    final key = '${emp!.backendId}_$_monthYearKey';
    // Already fetched (or being fetched) for this employee + month: do nothing.
    // The key is marked BEFORE the request starts, otherwise every rebuild
    // caused by the loading spinner would fire another request, and a failed
    // request would be retried forever.
    if (_fetchedFor == key && !force) return;
    _fetchedFor = key;
    final seq = ++_fetchSeq;

    if (mounted) {
      setState(() {
        _loadingGenerated = true;
        _generatedRows = null; // never show the previous month's slip under the new month's title
        _fetchError = null;
      });
    }
    try {
      final rows = await Get.find<ApiService>()
          .searchSalarySlipGene(employeeId: emp.backendId!, monthYear: _monthYearKey);
      if (!mounted || seq != _fetchSeq) return;
      setState(() {
        _generatedRows = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      });
    } catch (error) {
      if (!mounted || seq != _fetchSeq) return;
      setState(() {
        _generatedRows = null;
        _fetchError = error is ApiException
            ? error.message
            : 'Imeshindwa kupakua hati ya mshahara ya kipindi hiki. Angalia mtandao.';
      });
    } finally {
      if (mounted && seq == _fetchSeq) setState(() => _loadingGenerated = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeeCtrl = Get.find<EmployeeController>();
    final termsCtrl = Get.find<SalaryTermsController>();

    return Obx(() {
      final employees = employeeCtrl.employees;

      // Who was processed in the payroll run of the SELECTED month/year?
      // When that month has a payroll run, only those people are listed;
      // otherwise (no run yet) all employees stay selectable for an estimate.
      final mp = Get.find<MonthPayrollController>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) mp.load(_monthYearKey);
      });
      final processedIds = mp.loadedFor.value == _monthYearKey ? mp.byEmployee.keys.toSet() : <int>{};
      final onlyProcessed = processedIds.isNotEmpty;
      final pool = onlyProcessed
          ? employees.where((e) => e.backendId != null && processedIds.contains(e.backendId)).toList()
          : employees.toList();

      final active = pool.where((e) => e.status == 'Active').toList();
      final selectedInPool = _selected != null && pool.any((e) => e.id == _selected!.id) ? _selected : null;
      final current = selectedInPool ?? (active.isNotEmpty ? active.first : (pool.isNotEmpty ? pool.first : null));

      final filtered = pool.where((e) {
        final q = _employeeSearch.toLowerCase();
        return e.id.toLowerCase().contains(q) || e.fullName.toLowerCase().contains(q);
      }).toList();

      if (current == null) {
        return const Center(child: Text('Hakuna Wafanyakazi Waliopatikana.'));
      }

      // Kick off the fetch for whichever employee actually ended up
      // selected (covers the case where `current` was auto-picked because
      // `_selected` was still null) - guarded internally so it only does
      // real work when the employee/period actually changed.
      _currentForRetry = current;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeFetchGenerated(current));

      final hasGenerated = _generatedRows != null && _generatedRows!.isNotEmpty;
      final calc = hasGenerated
          ? buildResultFromGeneratedRows(current, _generatedRows!)
          : calculateEmployeePayroll(current, traTerms: termsCtrl.traTerms.toList());

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Pal.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Pal.border),
              ),
              child: ResponsiveHeaderBar(
                title: Text('SALARY SLIP / HATI YA MSHAHARA (PAYSLIP)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Pal.brandText)),
                actions: [
                  PopupMenuButton<String>(
                    tooltip: tr('Pakua PDF kutoka seva'),
                    enabled: hasGenerated && current.backendId != null,
                    onSelected: (style) => _downloadServerPdf(current, style),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'simple', child: Text('Payslip Rahisi (Simple)')),
                      PopupMenuItem(value: 'full', child: Text('Payslip Kamili (Full Detail)')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        border: Border.all(color: hasGenerated ? Pal.primary : Pal.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.picture_as_pdf_outlined, size: 16, color: hasGenerated ? Pal.primary : Pal.textMuted),
                        const SizedBox(width: 6),
                        Text('Pakua PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: hasGenerated ? Pal.primary : Pal.textMuted)),
                        Icon(Icons.arrow_drop_down, size: 18, color: hasGenerated ? Pal.primary : Pal.textMuted),
                      ]),
                    ),
                  ),
                  if (hasGenerated && current.backendId != null)
                    PopupMenuButton<String>(
                      tooltip: tr('Chapisha payslip'),
                      onSelected: (style) => _printServerPdf(current, style),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'simple', child: Text('Chapisha Rahisi (Simple)')),
                        PopupMenuItem(value: 'full', child: Text('Chapisha Kamili (Full Detail)')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: Pal.primary, borderRadius: BorderRadius.circular(8)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.print, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Chapisha (Print)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
                        ]),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => printSalarySlip(
                        emp: current,
                        calc: calc,
                        periodLabel: _selectedMonthLabel,
                        isOfficial: hasGenerated,
                      ),
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Chapisha (Print)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _statusBanner(hasGenerated),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              final employeePicker = _employeePickerCard(current, filtered,
                  onlyProcessed: onlyProcessed, processedCount: processedIds.length);
              final monthPicker = _monthPickerCard();
              if (isNarrow) {
                return Column(children: [employeePicker, const SizedBox(height: 16), monthPicker]);
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: employeePicker),
                    const SizedBox(width: 16),
                    Expanded(child: monthPicker),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            _payslipCard(current, calc),
          ],
        ),
      );
    });
  }

  Widget _statusBanner(bool hasGenerated) {
    if (_loadingGenerated) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Pal.surfaceAlt, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Inaangalia kama payroll imeshaendeshwa kwa kipindi hiki...',
              style: TextStyle(fontSize: 11, color: Pal.textSecondary)),
        ]),
      );
    }
    if (_fetchError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Pal.tint(Colors.red), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.error_outline, size: 15, color: Pal.fg(Colors.red.shade800)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_fetchError!,
                style: TextStyle(fontSize: 11, color: Pal.fg(Colors.red.shade900), fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => _maybeFetchGenerated(_selected ?? widget.initialEmployee ?? _currentForRetry, force: true),
            child: const Text('Jaribu Tena', style: TextStyle(fontSize: 11)),
          ),
        ]),
      );
    }
    if (hasGenerated) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Pal.tint(Colors.green), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.verified, size: 15, color: Pal.fg(Colors.green.shade700)),
          const SizedBox(width: 8),
          Text('HATI HALISI - imetokana na Payroll iliyoendeshwa kikamilifu kwa kipindi hiki.',
              style: TextStyle(fontSize: 11, color: Pal.fg(Colors.green.shade800), fontWeight: FontWeight.bold)),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Pal.tint(Colors.orange), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(Icons.info_outline, size: 15, color: Pal.fg(Colors.orange.shade800)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'MAKADIRIO TU - Payroll rasmi bado haijaendeshwa kwa $_selectedMonthLabel. Nenda "Endesha Payroll" kuzalisha hati halisi.',
            style: TextStyle(fontSize: 11, color: Pal.fg(Colors.orange.shade900), fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------------
  // 1. Employee picker
  // ---------------------------------------------------------------------

  Widget _employeePickerCard(Employee current, List<Employee> filtered,
      {bool onlyProcessed = false, int processedCount = 0}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('1. Chagua Mfanyakazi:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Pal.brandText)),
          const SizedBox(height: 4),
          Text(
            onlyProcessed
                ? 'Wafanyakazi $processedCount waliofanyiwa payroll ya $_selectedMonthLabel'
                : 'Hakuna payroll iliyoendeshwa kwa $_selectedMonthLabel - wafanyakazi wote wanaonyeshwa (makadirio tu)',
            style: TextStyle(fontSize: 10, color: onlyProcessed ? Pal.fg(Colors.green.shade800) : Pal.fg(Colors.orange.shade900)),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
                isDense: true, prefixIcon: Icon(Icons.search, size: 16), hintText: tr('Tafuta mfanyakazi kwa jina au ID...')),
            onChanged: (v) => setState(() => _employeeSearch = v),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filtered.map((e) {
                  final isSelected = current.id == e.id;
                  return ChoiceChip(
                    label: Text('${e.id} - ${e.fullName}', style: const TextStyle(fontSize: 10.5)),
                    selected: isSelected,
                    selectedColor: _brandBlue,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Pal.text),
                    onSelected: (_) => setState(() => _selected = e),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 2. Month / period picker — functional dropdown, mirrors the <select> in
  //    the original SalarySlipView.tsx.
  // ---------------------------------------------------------------------

  Widget _monthPickerCard() {
    final years = List.generate(3, (i) => DateTime.now().year - i);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('2. Mwezi wa Mshahara:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Pal.brandText)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  value: _selectedMonthIndex,
                  decoration: InputDecoration(isDense: true, labelText: tr('Mwezi')),
                  items: List.generate(
                    _swahiliMonths.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text('${_swahiliMonths[i]} (Mwezi wa ${i + 1})', style: const TextStyle(fontSize: 11.5)),
                    ),
                  ),
                  onChanged: (v) => setState(() => _selectedMonthIndex = v ?? _selectedMonthIndex),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: InputDecoration(isDense: true, labelText: tr('Mwaka')),
                  items: years
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 11.5))))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedYear = v ?? _selectedYear),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Pal.tint(Colors.blue), borderRadius: BorderRadius.circular(10)),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 10.5, color: Pal.fg(Colors.blue.shade900)),
                children: [
                  TextSpan(text: tr('Mshahara kwa ajili ya: ')),
                  TextSpan(text: tr(_selectedMonthLabel), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 3. Printable payslip card
  // ---------------------------------------------------------------------

  Widget _payslipCard(Employee emp, PayrollCalculationResult calc) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _brandBlue, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Letterhead ---
          LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 560;
            // The logo stands on BOTH sides of the title (left and right).
            final logoSize = isNarrow ? 48.0 : 64.0;
            final logoAndOrg = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TugheLogo(size: logoSize, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('TANZANIA UNION OF GOVERNMENT AND HEALTH EMPLOYEES',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Pal.brandText)),
                      const SizedBox(height: 2),
                      Text('Chama cha Wafanyakazi wa Serikali na Afya Tanzania (TUGHE)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Pal.brandText)),
                      const SizedBox(height: 2),
                      Text('S.L.P 463, Dodoma / Dar es Salaam - Tanzania | Email: info@tughe.or.tz',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9.5, color: Pal.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TugheLogo(size: logoSize, radius: 14),
              ],
            );

            final periodBadge = Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _brandBlue, borderRadius: BorderRadius.circular(8)),
                  child: const Text('SALARY SLIP / HATI YA MSHAHARA',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 4),
                Text('KIPINDI: ${_selectedMonthLabel.toUpperCase()}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [logoAndOrg, const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: periodBadge)],
            );
          }),
          const SizedBox(height: 16),
          const Divider(color: _brandBlue, thickness: 1.4, height: 1),
          const SizedBox(height: 20),

          // --- Employee details grid ---
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Pal.surfaceAlt, borderRadius: BorderRadius.circular(12)),
            child: LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth < 480 ? 1 : (constraints.maxWidth < 760 ? 2 : 3);
              final retirementDate = computeRetirementDateIso(emp.dateOfBirth);
              final details = [
                ('Namba ya Mfanyakazi (ID)', emp.id, true),
                ('Jina Kamili la Mfanyakazi', emp.fullName, false),
                ('Cheo / Kazi (Occupation)', emp.salaryStatus?.occupation ?? 'Kazi haijawekwa', false),
                ('Kituo cha Kazi (Work Station)', emp.salaryStatus?.workStation ?? 'Makao Makuu', false),
                ('Jina la Benki', emp.salaryStatus?.bankName ?? '-', false),
                ('Namba ya Akaunti ya Benki', emp.salaryStatus?.bankAccountNumber ?? '-', false),
                ('Tarehe ya Kuzaliwa', emp.dateOfBirth.isNotEmpty ? formatDate(emp.dateOfBirth) : '-', false),
                ('Tarehe ya Kustaafu (Miaka $defaultRetirementAge)',
                    retirementDate != null ? formatDate(retirementDate) : '-', false),
              ];
              final width = (constraints.maxWidth - (cols - 1) * 16) / cols;
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: details
                    .map((d) => SizedBox(
                          width: width,
                          child: _detailBox(d.$1, d.$2, emphasize: d.$3),
                        ))
                    .toList(),
              );
            }),
          ),
          const SizedBox(height: 20),

          // --- Earnings / Deductions ---
          LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;
            final earnings = _breakdownCard(
              headerTitle: '1. MAPATO NA POSHO (EARNINGS)',
              headerColor: _emerald800,
              baseLabel: 'Mshahara wa Msingi (Basic Salary)',
              baseValue: formatTZS(calc.basicSalary),
              subsectionLabel: 'Posho za Nyongeza:',
              items: [for (final a in calc.allowanceDetails) (a.name, formatTZS(a.amount))],
              itemPrefix: '+ ',
              totalLabel: 'MSHAHARA GHAFU (GROSS PAY):',
              totalValue: formatTZS(calc.grossSalary),
              accentColor: _emerald800,
            );
            final deductions = _breakdownCard(
              headerTitle: '2. MAKATO NA KODI (DEDUCTIONS)',
              headerColor: _red800,
              baseLabel: 'NSSF / PSSSF (10% Pension)',
              baseValue: formatTZS(calc.nssfDeduction),
              extraBaseRows: [('Kodi ya TRA PAYE (Tax Terms)', formatTZS(calc.traPayeTax))],
              subsectionLabel: 'Makato ya Arrears & Madeni:',
              items: [for (final a in calc.arrearsDetails) (a.name, formatTZS(a.amount))],
              itemPrefix: '- ',
              totalLabel: 'JUMLA YA MAKATO (TOTAL DEDUCTIONS):',
              totalValue: formatTZS(calc.totalDeductions),
              accentColor: _red800,
            );

            if (isNarrow) {
              return Column(children: [earnings, const SizedBox(height: 16), deductions]);
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: earnings),
                  const SizedBox(width: 20),
                  Expanded(child: deductions),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),

          // --- Net pay highlight ---
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: _brandBlue, borderRadius: BorderRadius.circular(16)),
            child: LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;
              final label = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('KIASI CHENYE MSHAHARA SAFI (TAKE HOME NET PAY)',
                      style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                  const SizedBox(height: 4),
                  Text('Kiasi kinachotumwa moja kwa moja kwenye Akaunti ya Benki (${emp.salaryStatus?.bankName ?? "-"})',
                      style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                ],
              );
              final amount = Text(formatTZS(calc.netSalary),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24));

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, const SizedBox(height: 10), amount],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Expanded(child: label), const SizedBox(width: 16), amount],
              );
            }),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // --- Signature & official stamp footer ---
          LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 560;
            final signature = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Inathibitishwa na:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                const SizedBox(height: 28),
                Container(width: 190, height: 1, color: Colors.black38),
                const SizedBox(height: 4),
                Text('Mhasibu Mkuu wa Mshahara TUGHE', style: TextStyle(fontSize: 10.5, color: Pal.textSecondary)),
              ],
            );
            final stamp = Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: _brandBlue, width: 1.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children:  [
                  Text('CHAMA CHA TUGHE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Pal.brandText)),
                  Text('OFFICIAL PAYROLL STAMP',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Pal.brandText)),
                  SizedBox(height: 2),
                  Text('VERIFIED & APPROVED',
                      style: TextStyle(fontSize: 8, color: Pal.brandText, fontFamily: 'monospace')),
                ],
              ),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [signature, const SizedBox(height: 20), stamp],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [signature, stamp],
            );
          }),
        ],
      ),
    );
  }

  Widget _detailBox(String label, String value, {bool emphasize = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 9.5, color: Pal.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: emphasize ? 13 : 11.5,
                fontWeight: FontWeight.bold,
                color: emphasize ? Pal.brandText : Pal.text)),
      ],
    );
  }

  Widget _breakdownCard({
    required String headerTitle,
    required Color headerColor,
    required String baseLabel,
    required String baseValue,
    List<(String, String)> extraBaseRows = const [],
    required String subsectionLabel,
    required List<(String, String)> items,
    required String itemPrefix,
    required String totalLabel,
    required String totalValue,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Pal.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: headerColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(headerTitle,
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900)),
                ),
                const Text('KIASI (TZS)',
                    style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _breakdownRow(baseLabel, baseValue, bold: true),
                for (final r in extraBaseRows) ...[
                  const Divider(height: 14),
                  _breakdownRow(r.$1, r.$2, bold: true, valueColor: accentColor),
                ],
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(subsectionLabel,
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Pal.textMuted, letterSpacing: 0.3)),
                  const SizedBox(height: 4),
                  ...items.map((it) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 3),
                        child: _breakdownRow('$itemPrefix${it.$1}', it.$2, valueColor: accentColor),
                      )),
                ],
                const SizedBox(height: 10),
                Container(height: 2, color: headerColor),
                const SizedBox(height: 8),
                _breakdownRow(totalLabel, totalValue, bold: true, big: true, valueColor: accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value, {bool bold = false, bool big = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: big ? 12 : 11,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
                  color: Pal.text)),
        ),
        const SizedBox(width: 8),
        Text(value,
            style: TextStyle(
                fontSize: big ? 13 : 11,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                color: valueColor ?? Pal.text)),
      ],
    );
  }
}
