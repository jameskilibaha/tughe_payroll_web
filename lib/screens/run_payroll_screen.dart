import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../controllers/allowances_settings_controller.dart';
import '../controllers/arrears_settings_controller.dart';
import '../controllers/employee_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/payroll_controller.dart';
import '../models/employee.dart';
import '../models/master_arrear_setting.dart';
import '../utils/formatters.dart';
import 'widgets/live_payroll_panel.dart';
import 'widgets/period_status_card.dart';
import 'widgets/responsive_header_bar.dart';
import '../core/tr_text.dart';
import '../core/translations.dart';
import '../core/theme.dart';

const _brandBlue = Color(0xFF1E3A8A);
const _green700 = Color(0xFF15803D);
const _red700 = Color(0xFFB91C1C);

const _swahiliMonths = [
  'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni',
  'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba',
];

class RunPayrollScreen extends StatefulWidget {
  const RunPayrollScreen({super.key});

  @override
  State<RunPayrollScreen> createState() => _RunPayrollScreenState();
}

class _RunPayrollScreenState extends State<RunPayrollScreen> {
  late String _monthYear = _defaultMonthYear();
  final Set<int> _selectedIds = {};

  /// Is the live-payroll pop-up on screen right now?
  bool _liveDialogOpen = false;

  /// Shows the live view as a pop-up (once). The run continues if the pop-up is hidden.
  Future<void> _openLiveDialog() async {
    if (_liveDialogOpen || !mounted) return;
    setState(() => _liveDialogOpen = true);
    await showLivePayrollDialog(context, Get.find<PayrollController>());
    if (mounted) setState(() => _liveDialogOpen = false);
  }

  /// "Mara Moja" (once) arrears: master arrears id -> deduct this month?
  final Map<int, bool> _onceDeduct = {};

  /// master arrears id -> TZS amount typed by the admin (empty = each employee's own value)
  final Map<int, TextEditingController> _onceAmount = {};

  /// Default text of the amount box: the master arrear's default TZS value
  /// (percent arrears start empty - each employee is charged their own %).
  static String _defaultAmountText(MasterArrearSetting m) {
    if (m.deductionType == 'Percent' || m.defaultValue <= 0) return '';
    return plainAmount(m.defaultValue);
  }

  TextEditingController _amountCtrl(MasterArrearSetting m) =>
      _onceAmount.putIfAbsent(m.backendId!, () => TextEditingController(text: _defaultAmountText(m)));

  /// The amount to FORCE for everyone, or null when the admin left the default
  /// (each employee is then charged their own assigned value).
  double? _amountOverride(MasterArrearSetting m) {
    final text = _onceOnce(m.backendId!).trim().replaceAll(',', '');
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null) return null;
    if (m.deductionType != 'Percent' && value == m.defaultValue) return null; // untouched default
    return value;
  }

  @override
  void initState() {
    super.initState();
    // If a payroll run is still going on the server (e.g. the page was refreshed),
    // re-attach to it and keep showing its live progress.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctrl = Get.find<PayrollController>();
      await ctrl.resumeIfRunning();
      if (mounted && ctrl.liveRunning) _openLiveDialog();
    });
  }

  @override
  void dispose() {
    for (final c in _onceAmount.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<MasterArrearSetting> _onceArrears() => Get.find<ArrearsSettingsController>()
      .masterArrears
      .where((m) => !m.isChoice && m.backendId != null)
      .toList();

  /// The payload sent to the backend for every once-arrear.
  List<Map<String, dynamic>> _onceArrearsPayload() {
    return _onceArrears().map((m) {
      final id = m.backendId!;
      final deduct = _onceDeduct[id] ?? true; // default: deducted
      return {'arrearsId': id, 'deduct': deduct, 'amount': deduct ? _amountOverride(m) : null};
    }).toList();
  }

  String _onceOnce(int id) => _onceAmount[id]?.text ?? '';

  String _onceSummary() {
    final taken = <String>[];
    final skipped = <String>[];
    for (final m in _onceArrears()) {
      final id = m.backendId!;
      if (!(_onceDeduct[id] ?? true)) {
        skipped.add('• ${m.name}');
        continue;
      }
      final override = _amountOverride(m);
      final how = override != null
          ? formatTZS(override)
          : (m.deductionType == 'Percent'
              ? '${m.defaultValue}% ya mshahara wa kila mfanyakazi'
              : '${formatTZS(m.defaultValue)} (chaguo-msingi)');
      taken.add('• ${m.name}: $how');
    }
    final b = StringBuffer();
    if (taken.isNotEmpty) b.write('Makato ya mara moja yatakayokatwa:\n${taken.join('\n')}');
    if (skipped.isNotEmpty) {
      if (b.isNotEmpty) b.write('\n\n');
      b.write('Hayatakatwa mwezi huu:\n${skipped.join('\n')}');
    }
    return b.isEmpty ? 'Hakuna kato la mara moja.' : b.toString();
  }

  static String _defaultMonthYear() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static String _label(String monthYear) {
    final parts = monthYear.split('-');
    if (parts.length != 2) return monthYear;
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return monthYear;
    return '${_swahiliMonths[month - 1]} ${parts[0]}';
  }

  /// Last 12 months through the next 2, newest-relevant first.
  List<String> _monthOptions() {
    final now = DateTime.now();
    final options = <String>[];
    for (var offset = 2; offset >= -12; offset--) {
      final d = DateTime(now.year, now.month + offset);
      options.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }
    return options;
  }

  List<Employee> _eligibleEmployees(EmployeeController ctrl) {
    return ctrl.employees
        .where((e) => e.status == 'Active' && e.salaryStatus != null && e.backendId != null)
        .toList();
  }

  Future<bool> _confirm({required String title, required String message, required Color color}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Ghairi')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ndiyo, Endelea'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _runPayroll(PayrollController payrollCtrl, int eligibleCount) async {
    final scope = _selectedIds.isEmpty
        ? 'wafanyakazi WOTE walio hai ($eligibleCount)'
        : '${_selectedIds.length} wafanyakazi uliowachagua';
    final ok = await _confirm(
      title: 'Thibitisha Kuendesha Payroll',
      message: 'Utaendesha payroll ya ${_label(_monthYear)} kwa $scope.\n\n${_onceSummary()}\n\nEndelea?',
      color: _green700,
    );
    if (!ok) return;
    // Runs in the background on the server and streams its progress live (WebSocket).
    final started = await payrollCtrl.generateLive(
      monthYear: _monthYear,
      employeeIds: _selectedIds.toList(),
      onceArrears: _onceArrearsPayload(),
    );
    if (started && mounted) _openLiveDialog(); // live progress as a pop-up
  }

  Future<void> _reversePayroll(PayrollController payrollCtrl, int eligibleCount) async {
    final scope = _selectedIds.isEmpty
        ? 'wafanyakazi WOTE'
        : '${_selectedIds.length} wafanyakazi uliowachagua';
    final ok = await _confirm(
      title: 'Thibitisha Kubatilisha Payroll',
      message:
          'Hii itafuta kabisa kumbukumbu zote za payroll ya ${_label(_monthYear)} kwa $scope (salary slips, malipo ya makato na posho). Hatua hii haiwezi kurudishwa nyuma. Endelea?',
      color: _red700,
    );
    if (!ok) return;
    await payrollCtrl.reverse(monthYear: _monthYear, employeeIds: _selectedIds.toList());
  }

  /// Shows every "SPECIAL" (apply-to-everyone) arrears/allowance with its
  /// CURRENT value - e.g. NSSF's contribution rate - so the admin can spot
  /// and fix a rate that changed this month (up or down) BEFORE running
  /// payroll, instead of finding out after the fact.
  /// Arrears with frequency "Mara Moja": the admin decides, BEFORE running
  /// payroll, whether each one is deducted this month and how much (TZS).
  Widget _onceArrearsCard() {
    return Obx(() {
      final list = _onceArrears();
      if (list.isEmpty) return const SizedBox.shrink();
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
            const Text('3. Makato ya Mara Moja (Ones) - Yakatwe Mwezi Huu?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              'Makato haya yamechaguliwa kwa chaguo-msingi (kiasi chake cha kawaida). Unaweza kuondoa tiki ili lisikatwe mwezi huu, au kubadilisha kiasi (TZS) kikatwe kwa wote. Ukifuta kiasi, kila mfanyakazi anakatwa kiasi chake alichowekewa.',
              style: TextStyle(fontSize: 10.5, color: Pal.textMuted),
            ),
            const SizedBox(height: 10),
            ...list.map((m) {
              final id = m.backendId!;
              final on = _onceDeduct[id] ?? true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: on,
                      onChanged: (v) => setState(() => _onceDeduct[id] = v ?? false),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${m.name}  •  ${m.deductionType == 'Percent' ? '${m.defaultValue}%' : formatTZS(m.defaultValue)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _amountCtrl(m),
                        enabled: on,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          labelText: tr('Kiasi cha kukata (TZS)'),
                          hintText: tr('tupu = kiasi cha kila mfanyakazi'),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  Widget _variableRatesReviewCard() {
    return Obx(() {
      final arrears = Get.find<ArrearsSettingsController>()
          .masterArrears
          .where((m) => m.arrearsType == 'Special')
          .toList();
      final allowances = Get.find<AllowancesSettingsController>()
          .masterAllowances
          .where((m) => m.allowanceType == 'Special')
          .toList();

      if (arrears.isEmpty && allowances.isEmpty) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Pal.tint(Colors.amber),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.fact_check_outlined, size: 16, color: Pal.fg(Colors.amber.shade900)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('KAGUA KWANZA: Makato/Posho Yanayoweza Kubadilika Kila Mwezi (SPECIAL)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              'Mfano NSSF/mchango - hakikisha thamani hizi ni sahihi kwa mwezi huu KABLA ya kuendesha payroll. '
              'Ukibadilisha, tumia kitufe cha "Sasisha kwa Wote" kwenye Settings ili zibadilike kwa wote mara moja.',
              style: TextStyle(fontSize: 10.5, color: Pal.fg(Colors.amber.shade900)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in arrears)
                  _rateChip(a.name, a.deductionType == 'Percent' ? '${a.defaultValue}%' : formatTZS(a.defaultValue)),
                for (final al in allowances)
                  _rateChip(al.name, al.additionType == 'Percent' ? '${al.defaultValue}%' : formatTZS(al.defaultValue)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => Get.find<NavigationController>().goTo('settings_arrears'),
                  icon: const Icon(Icons.trending_down, size: 14),
                  label: const Text('Nenda Makato Settings', style: TextStyle(fontSize: 10.5)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => Get.find<NavigationController>().goTo('settings_allowances'),
                  icon: const Icon(Icons.card_giftcard, size: 14),
                  label: const Text('Nenda Posho Settings', style: TextStyle(fontSize: 10.5)),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _rateChip(String name, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade300)),
      child: Text('$name: $value', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeeCtrl = Get.find<EmployeeController>();
    final payrollCtrl = Get.find<PayrollController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveHeaderBar(
          title: Text('Endesha Payroll (Run Payroll)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Pal.brandText)),
          subtitle: Text('Chagua mwezi na wafanyakazi, kisha endesha au batilisha payroll',
              style: TextStyle(fontSize: 12, color: Pal.textSecondary)),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _variableRatesReviewCard(),
                const SizedBox(height: 16),
                // Month picker
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Pal.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Pal.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. Chagua Mwezi wa Payroll',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _monthYear,
                        decoration: const InputDecoration(isDense: true),
                        items: _monthOptions()
                            .map((m) => DropdownMenuItem(value: m, child: Text(_label(m))))
                            .toList(),
                        onChanged: (v) => setState(() => _monthYear = v ?? _monthYear),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PeriodStatusCard(month: _monthYear),
                _onceArrearsCard(),
                const SizedBox(height: 16),

                // Employee selection
                Obx(() {
                  final eligible = _eligibleEmployees(employeeCtrl);
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
                            const Text('2. Chagua Wafanyakazi',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              _selectedIds.isEmpty
                                  ? 'Wote (${eligible.length})'
                                  : '${_selectedIds.length} / ${eligible.length} wamechaguliwa',
                              style: TextStyle(fontSize: 11, color: Pal.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Usipochagua yeyote, payroll itaendeshwa kwa wafanyakazi WOTE walio hai wenye taarifa za mshahara.',
                          style: TextStyle(fontSize: 10.5, color: Pal.textMuted),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => setState(() => _selectedIds
                                ..clear()
                                ..addAll(eligible.map((e) => e.backendId!))),
                              icon: const Icon(Icons.check_box_outlined, size: 15),
                              label: const Text('Chagua Wote', style: TextStyle(fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => setState(() => _selectedIds.clear()),
                              icon: const Icon(Icons.check_box_outline_blank, size: 15),
                              label: const Text('Ondoa Wote', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        if (eligible.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Hakuna mfanyakazi mwenye Hali ya Mshahara iliyowekwa bado. Weka "Hali ya Mshahara" kwa wafanyakazi kabla ya kuendesha payroll.',
                              style: TextStyle(color: Pal.textMuted, fontSize: 11.5),
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 360),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: eligible.length,
                              itemBuilder: (context, i) {
                                final e = eligible[i];
                                final backendId = e.backendId!;
                                final checked = _selectedIds.contains(backendId);
                                return CheckboxListTile(
                                  dense: true,
                                  value: checked,
                                  onChanged: (_) => setState(() {
                                    if (checked) {
                                      _selectedIds.remove(backendId);
                                    } else {
                                      _selectedIds.add(backendId);
                                    }
                                  }),
                                  title: Text(e.fullName, style: const TextStyle(fontSize: 12.5)),
                                  subtitle: Text(
                                    '${e.id} • ${e.salaryStatus?.occupation ?? '-'}',
                                    style: TextStyle(fontSize: 10.5, color: Pal.textMuted),
                                  ),
                                  controlAffinity: ListTileControlAffinity.leading,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Actions
                Obx(() {
                  final eligibleCount = _eligibleEmployees(employeeCtrl).length;
                  final running = payrollCtrl.isRunning.value;
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: running ? null : () => _runPayroll(payrollCtrl, eligibleCount),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _green700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14)),
                          icon: running
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Endesha Payroll'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: running ? null : () => _reversePayroll(payrollCtrl, eligibleCount),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: _red700,
                              side: const BorderSide(color: _red700),
                              padding: const EdgeInsets.symmetric(vertical: 14)),
                          icon: const Icon(Icons.undo, size: 18),
                          label: const Text('Batilisha Payroll'),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 16),

                // Live progress of the run (also re-attaches after a page refresh)
                // Slim status bar while the pop-up is hidden/after it was closed mid-run
                if (!_liveDialogOpen) ...[
                  LivePayrollStrip(controller: payrollCtrl, onOpen: _openLiveDialog),
                  const SizedBox(height: 16),
                ],

                // Result
                Obx(() {
                  final result = payrollCtrl.lastResult.value;
                  final action = payrollCtrl.lastAction.value;
                  if (result == null) return const SizedBox.shrink();
                  return _ResultCard(action: action, result: result);
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.action, required this.result});
  final String action;
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final isGenerate = action == 'generate';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGenerate ? Pal.tint(Colors.green) : Pal.tint(Colors.orange),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isGenerate ? Colors.green.shade200 : Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isGenerate ? 'Matokeo ya Kuendesha Payroll' : 'Matokeo ya Kubatilisha Payroll',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (isGenerate) ...[
            Text('Wafanyakazi waliofanikiwa: ${result['employeesProcessed'] ?? 0}',
                style: TextStyle(fontSize: 12, color: Pal.fg(_green700), fontWeight: FontWeight.w600)),
            Text('Wafanyakazi waliokwisha kufanyiwa (waliorukwa): ${result['employeesAlreadyDone'] ?? 0}',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            Text('Wafanyakazi wenye matatizo: ${result['employeesWithProblems'] ?? 0}',
                style: TextStyle(
                    fontSize: 12,
                    color: (result['employeesWithProblems'] ?? 0) > 0 ? Pal.fg(_red700) : Pal.textSecondary)),
            if ((result['debtsCleared'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              const Text('Madeni yaliyokwisha mwezi huu (makato yameondolewa):',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ...((result['debtsCleared'] as List).map((d) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• ${d['employee']}: ${(d['debts'] as List).join(', ')}',
                        style: TextStyle(fontSize: 11, color: Pal.fg(Colors.teal.shade700))),
                  ))),
            ],
            if ((result['problems'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              const Text('Maelezo ya matatizo:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ...((result['problems'] as List).map((p) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• employeeStatus_id ${p['employeeStatus_id']}: ${p['detail']}',
                        style: TextStyle(fontSize: 11, color: Pal.textSecondary)),
                  ))),
            ],
          ] else ...[
            Text('Salary slips zilizofutwa: ${result['salarySlipsRemoved'] ?? 0}', style: const TextStyle(fontSize: 12)),
            Text('Malipo ya makato yaliyofutwa: ${result['arrearsPaymentsRemoved'] ?? 0}',
                style: const TextStyle(fontSize: 12)),
            Text('Malipo ya posho yaliyofutwa: ${result['allowancesPaymentsRemoved'] ?? 0}',
                style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
