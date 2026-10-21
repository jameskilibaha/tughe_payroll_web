import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/employee_controller.dart';
import '../../controllers/statutory_controller.dart';
import '../../models/employee.dart';
import '../../models/salary_status.dart';
import '../../utils/formatters.dart';
import 'form_kit.dart';
import 'modal_header_banner.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';

// Matches the original EmployeeSalaryStatusModal.tsx: blue-900 to indigo-900
// gradient header.
const _blue900 = Color(0xFF1E3A8A);
const _indigo900 = Color(0xFF312E81);

Future<void> showSalaryStatusDialog(BuildContext context, Employee employee) {
  return showDialog(context: context, builder: (_) => _SalaryStatusDialog(employee: employee));
}

class _SalaryStatusDialog extends StatefulWidget {
  const _SalaryStatusDialog({required this.employee});
  final Employee employee;

  @override
  State<_SalaryStatusDialog> createState() => _SalaryStatusDialogState();
}

class _SalaryStatusDialogState extends State<_SalaryStatusDialog> {
  late final _occupationCtrl =
      TextEditingController(text: widget.employee.salaryStatus?.occupation ?? '');
  late final _workStationCtrl =
      TextEditingController(text: widget.employee.salaryStatus?.workStation ?? '');
  late final _basicSalaryCtrl =
      TextEditingController(text: widget.employee.salaryStatus == null ? '' : plainAmount(widget.employee.salaryStatus!.basicSalary));
  late final _bankAccountCtrl =
      TextEditingController(text: widget.employee.salaryStatus?.bankAccountNumber ?? '');
  String _bankName = 'NMB Bank';

  // statutory details of the employee (TIN, pension fund, HESLB, last working day) - kept by the server
  final _tin = TextEditingController();
  final _fundNo = TextEditingController();
  final _exitDate = TextEditingController();
  String _fund = 'NSSF';
  bool _heslb = false;
  String? _statutoryError;
  bool _statutoryLoaded = false;
  List<Map<String, dynamic>> _history = const [];

  final _banks = const ['NMB Bank', 'CRDB Bank', 'NBC Bank', 'Equity Bank', 'Exim Bank', 'DTB Bank'];

  @override
  void initState() {
    super.initState();
    _bankName = widget.employee.salaryStatus?.bankName ?? _banks.first;
    _loadStatutory();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final id = widget.employee.backendId;
    if (id == null) return;
    final h = await Get.find<StatutoryController>().salaryHistory(id);
    if (mounted) setState(() => _history = h.reversed.toList());
  }

  @override
  void dispose() {
    _tin.dispose();
    _fundNo.dispose();
    _exitDate.dispose();
    super.dispose();
  }

  Future<void> _loadStatutory() async {
    final id = widget.employee.backendId;
    if (id == null) return;
    final p = await Get.find<StatutoryController>().employeeProfile(id);
    if (!mounted) return;
    setState(() {
      if (p != null) {
        _tin.text = (p['tin'] as String?) ?? '';
        _fund = (p['socialFund'] as String?) ?? 'NSSF';
        _fundNo.text = (p['socialFundNo'] as String?) ?? '';
        _heslb = p['heslb'] == true;
        _exitDate.text = ((p['exitDate'] as String?) ?? '').split('T').first;
        _statutoryLoaded = true;
      }
    });
  }

  bool _isSaving = false;

  Future<void> _save() async {
    final basicSalary = double.tryParse(_basicSalaryCtrl.text.trim()) ?? 0;
    if (basicSalary <= 0) {
      setState(() => _salaryError = 'Weka mshahara wa msingi (zaidi ya 0).');
      return;
    }
    final status = SalaryStatus(
      occupation: _occupationCtrl.text.trim(),
      workStation: _workStationCtrl.text.trim(),
      basicSalary: basicSalary,
      bankName: _bankName,
      bankAccountNumber: _bankAccountCtrl.text.trim(),
    );
    setState(() {
      _isSaving = true;
      _statutoryError = null;
    });
    await Get.find<EmployeeController>().saveSalaryStatus(widget.employee.id, status);
    // the statutory details are saved too (only when they were loaded, so a failed load never wipes them)
    final id = widget.employee.backendId;
    if (id != null && _statutoryLoaded) {
      final failure = await Get.find<StatutoryController>().saveEmployeeProfile(id, {
        'tin': _tin.text.trim(),
        'socialFund': _fund,
        'socialFundNo': _fundNo.text.trim(),
        'heslb': _heslb,
        'exitDate': _exitDate.text.trim().isEmpty ? null : _exitDate.text.trim(),
      });
      if (failure != null && mounted) {
        setState(() {
          _isSaving = false;
          _statutoryError = 'Hali ya mshahara imehifadhiwa, lakini taarifa za kisheria hazikuhifadhiwa: $failure';
        });
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  String? _salaryError;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModalHeaderBanner(
              icon: Icons.attach_money,
              title: 'Hali ya Mshahara (Salary Status)',
              subtitle: 'Weka Wadhifa, Kituo, Mshahara wa Msingi na Taarifa za Benki kwa ${widget.employee.fullName}',
              gradientColors: const [_blue900, _indigo900],
              iconColor: Colors.greenAccent.shade100,
              subtitleColor: Colors.blue.shade100,
              onClose: _isSaving ? null : () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FormNotice('${tr('Mfanyakazi: ')}${widget.employee.fullName} (${widget.employee.id})', kind: NoticeKind.info),
                    const FormSection('Kazi', icon: Icons.work_outline),
                    FormGrid(children: [
                      AppTextField(label: 'Wadhifa / Cheo (Occupation)', controller: _occupationCtrl, textCapitalization: TextCapitalization.words),
                      AppTextField(label: 'Kituo cha Kazi (Work Station)', controller: _workStationCtrl, textCapitalization: TextCapitalization.words),
                    ]),
                    const SizedBox(height: 8),
                    const FormSection('Mshahara', icon: Icons.payments_outlined),
                    AppTextField(
                      label: 'Mshahara wa Msingi (Basic Salary - TZS)',
                      controller: _basicSalaryCtrl,
                      icon: Icons.attach_money,
                      required: true,
                      prefixText: 'TZS ',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))],
                      helper: 'Unaweza kuweka desimali hadi tarakimu 3; kiasi kinahifadhiwa kamili.',
                      errorText: _salaryError,
                      onChanged: (_) {
                        if (_salaryError != null) setState(() => _salaryError = null);
                      },
                    ),
                    const SizedBox(height: 8),
                    const FormSection('Benki', icon: Icons.account_balance_outlined),
                    FormGrid(children: [
                      AppDropdown<String>(
                        label: 'Benki (Bank)',
                        value: _bankName,
                        items: _banks,
                        onChanged: (v) => setState(() => _bankName = v ?? _bankName),
                      ),
                      AppTextField(
                        label: 'Namba ya Akaunti ya Benki',
                        controller: _bankAccountCtrl,
                        icon: Icons.numbers,
                        keyboardType: TextInputType.number,
                      ),
                    ]),
                    const SizedBox(height: 8),
                    const FormSection('Taarifa za Kisheria', icon: Icons.gavel_outlined, hint: 'Zinatumika kwenye PAYE, pensheni, HESLB na ripoti za TRA/NSSF/PSSSF.'),
                    if (_statutoryError != null) FormNotice(_statutoryError!),
                    FormGrid(children: [
                      AppTextField(label: 'TIN (Namba ya Mlipakodi)', controller: _tin, icon: Icons.badge_outlined, keyboardType: TextInputType.number),
                      AppDropdown<String>(
                        label: 'Mfuko wa Pensheni',
                        value: _fund,
                        items: const ['NSSF', 'PSSSF', 'NONE'],
                        labelOf: (v) => v == 'NSSF' ? 'NSSF' : (v == 'PSSSF' ? 'PSSSF (watumishi wa umma)' : 'Hakuna mfuko'),
                        onChanged: (v) => setState(() => _fund = v ?? _fund),
                      ),
                      AppTextField(label: 'Namba ya Mfuko (NSSF/PSSSF)', controller: _fundNo, icon: Icons.numbers, enabled: _fund != 'NONE'),
                      AppDateField(label: 'Siku ya Mwisho Kazini (akiondoka)', controller: _exitDate, firstDate: DateTime(2000), lastDate: DateTime(DateTime.now().year + 2, 12, 31), onPicked: () => setState(() {})),
                    ]),
                    if (_exitDate.text.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _exitDate.clear()),
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Futa tarehe ya kuondoka'),
                        ),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ana mkopo wa HESLB', style: TextStyle(fontSize: 12.5)),
                      subtitle: const Text('Kato la HESLB linakatwa kila mwezi kwa kiwango kilichopo kwenye Mipangilio ya Kisheria.', style: TextStyle(fontSize: 10.5)),
                      value: _heslb,
                      onChanged: (v) => setState(() => _heslb = v),
                    ),
                    if (_history.length > 1)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text('${tr('Historia ya Mshahara')} (${_history.length})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        children: [
                          for (final h in _history)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(h['current'] == true ? Icons.radio_button_checked : Icons.history, size: 18),
                              title: Text(formatTZS((h['basic'] as num?) ?? 0), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              subtitle: Text('${((h['since'] as String?) ?? '').split('T').first}  |  ${h['occupation'] ?? ''}, ${h['workstation'] ?? ''}', style: const TextStyle(fontSize: 10.5)),
                              trailing: h['change'] == null
                                  ? null
                                  : Text(
                                      '${(h['change'] as num) >= 0 ? '+' : ''}${formatTZS(h['change'] as num)}',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: (h['change'] as num) >= 0 ? Colors.green.shade700 : Colors.red.shade700),
                                    ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
            FormActions(
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _save,
              busy: _isSaving,
              submitLabel: 'Hifadhi',
            ),
          ],
        ),
      ),
    );
  }
}
