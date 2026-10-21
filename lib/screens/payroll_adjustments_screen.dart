import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/employee_controller.dart';
import '../controllers/statutory_controller.dart';
import '../core/theme.dart';
import '../core/tr_snack.dart';
import '../core/tr_text.dart';
import '../core/translations.dart';
import '../models/employee.dart';
import '../utils/formatters.dart';
import 'widgets/app_status_views.dart';
import 'widgets/form_kit.dart';

/// "Marekebisho ya Mwezi": the one-off items of a month that the payroll run picks up - overtime, a
/// bonus, back pay, a one-off deduction, days of unpaid leave. They have to be entered BEFORE the
/// payroll of that month is run for the employee.
class PayrollAdjustmentsScreen extends StatefulWidget {
  const PayrollAdjustmentsScreen({super.key});

  @override
  State<PayrollAdjustmentsScreen> createState() => _PayrollAdjustmentsScreenState();
}

class _PayrollAdjustmentsScreenState extends State<PayrollAdjustmentsScreen> {
  final _ctrl = Get.find<StatutoryController>();
  late String _month;

  late final List<String> _months = () {
    final now = DateTime.now();
    return [for (var i = -1; i < 12; i++) _fmt(DateTime(now.year, now.month - i, 1))];
  }();

  static String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static const _kinds = ['OVERTIME', 'BONUS', 'BACKPAY', 'DEDUCTION', 'UNPAID_LEAVE'];
  static const _kindNames = {
    'OVERTIME': 'Muda wa Ziada (Overtime)',
    'BONUS': 'Bonasi',
    'BACKPAY': 'Malipo ya Nyuma (Back Pay)',
    'DEDUCTION': 'Kato la Mara Moja',
    'UNPAID_LEAVE': 'Likizo Bila Malipo',
  };
  static const _kindIcons = {
    'OVERTIME': Icons.more_time,
    'BONUS': Icons.card_giftcard,
    'BACKPAY': Icons.history,
    'DEDUCTION': Icons.remove_circle_outline,
    'UNPAID_LEAVE': Icons.event_busy_outlined,
  };

  @override
  void initState() {
    super.initState();
    _month = _fmt(DateTime.now());
    _ctrl.loadAdjustments(_month);
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Futa Marekebisho'),
            content: Text('Kufuta "${a['kindLabel']}" ya ${a['employeeName']}?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Ghairi')),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Pal.danger, foregroundColor: Colors.white),
                child: const Text('Ndiyo, Futa'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    final failure = await _ctrl.deleteAdjustment((a['id'] as num).toInt(), _month);
    if (failure != null) trSnack('Imeshindikana', failure);
  }

  Future<void> _add() async {
    final added = await showDialog<bool>(context: context, builder: (_) => _AddAdjustmentDialog(month: _month, ctrl: _ctrl));
    if (added == true) trSnack('Imefanikiwa', 'Marekebisho yameongezwa. Yatatumika payroll ya $_month ikiendeshwa.');
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = _ctrl.adjustments.toList();
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('MAREKEBISHO YA MWEZI (ADJUSTMENTS)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Pal.brandText)),
            const SizedBox(height: 4),
            Text('Malipo na makato ya mara moja ya mwezi: muda wa ziada, bonasi, malipo ya nyuma, kato la mara moja na siku za likizo bila malipo. Yaingize KABLA ya kuendesha payroll ya mwezi huo.',
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
                      _ctrl.loadAdjustments(v);
                    },
                  ),
                ),
                ElevatedButton.icon(onPressed: _add, icon: const Icon(Icons.add, size: 18), label: const Text('Ongeza Marekebisho')),
              ],
            ),
            const SizedBox(height: 14),
            if (_ctrl.loadingAdjustments.value && list.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: AppLoadingIndicator(message: 'Inapakua marekebisho...'))
            else if (_ctrl.adjustmentsError.value != null)
              AppErrorRetryView(message: _ctrl.adjustmentsError.value!, onRetry: () => _ctrl.loadAdjustments(_month))
            else if (list.isEmpty)
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.border)),
                child: Column(children: [
                  Icon(Icons.tune, size: 38, color: Pal.textMuted),
                  const SizedBox(height: 10),
                  Text('Hakuna marekebisho ya mwezi $_month.', style: TextStyle(color: Pal.textSecondary)),
                ]),
              )
            else
              Container(
                decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.border)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      _row(list[i]),
                      if (i != list.length - 1) Divider(height: 1, color: Pal.border),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      );
    });
  }

  Widget _row(Map<String, dynamic> a) {
    final kind = a['kind'] as String;
    final isEarning = kind == 'OVERTIME' || kind == 'BONUS' || kind == 'BACKPAY';
    final amountText = kind == 'UNPAID_LEAVE' ? '${plainAmount((a['days'] as num?) ?? 0)} ${tr('siku')}' : formatTZS((a['amount'] as num?) ?? 0);
    final color = isEarning ? Colors.green : (kind == 'DEDUCTION' ? Colors.red : Colors.orange);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(radius: 17, backgroundColor: Pal.tint(color), child: Icon(_kindIcons[kind] ?? Icons.tune, size: 17, color: Pal.fg(color.shade700))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a['employeeName']}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${_kindNames[kind] ?? a['kindLabel']}${(a['description'] as String? ?? '').isEmpty ? '' : ' - ${a['description']}'}'
                  '${isEarning ? (a['taxable'] == true ? '  |  ${tr('Inatozwa kodi')}' : '  |  ${tr('Haitozwi kodi')}') : ''}',
                  style: TextStyle(fontSize: 11, color: Pal.textSecondary),
                ),
              ],
            ),
          ),
          Text('${isEarning ? '+' : '-'} $amountText', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Pal.fg(color.shade700))),
          IconButton(tooltip: tr('Futa'), icon: Icon(Icons.delete_outline, color: Pal.danger, size: 20), onPressed: () => _delete(a)),
        ],
      ),
    );
  }
}

class _AddAdjustmentDialog extends StatefulWidget {
  const _AddAdjustmentDialog({required this.month, required this.ctrl});

  final String month;
  final StatutoryController ctrl;

  @override
  State<_AddAdjustmentDialog> createState() => _AddAdjustmentDialogState();
}

class _AddAdjustmentDialogState extends State<_AddAdjustmentDialog> {
  final _employeeField = TextEditingController();
  final _amount = TextEditingController();
  final _days = TextEditingController();
  final _description = TextEditingController();
  Employee? _employee;
  String _kind = 'OVERTIME';
  bool _taxable = true;
  bool _saving = false;
  final Map<String, String> _errors = {};
  String? _failure;

  bool get _isLeave => _kind == 'UNPAID_LEAVE';
  bool get _isEarning => _kind == 'OVERTIME' || _kind == 'BONUS' || _kind == 'BACKPAY';

  @override
  void dispose() {
    _employeeField.dispose();
    _amount.dispose();
    _days.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final errors = <String, String>{};
    if (_employee == null || _employee!.backendId == null) errors['employee'] = 'Chagua mfanyakazi kutoka kwenye orodha.';
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    final days = double.tryParse(_days.text.trim().replaceAll(',', '.'));
    if (_isLeave) {
      if (days == null || days <= 0 || days > 31) errors['days'] = 'Weka siku kati ya 1 na 31.';
    } else if (amount == null || amount <= 0) {
      errors['amount'] = 'Weka kiasi kikubwa kuliko 0.';
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      _failure = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _saving = true);
    final failure = await widget.ctrl.addAdjustment({
      'employeeId': _employee!.backendId,
      'monthYear': widget.month,
      'kind': _kind,
      'description': _description.text.trim(),
      if (_isLeave) 'days': days else 'amount': amount,
      'taxable': _isEarning ? _taxable : false,
    });
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _failure = failure;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final employees = Get.find<EmployeeController>().employees.where((e) => e.backendId != null && e.status != 'Blocked').toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
              child: Row(children: [
                Icon(Icons.tune, color: Pal.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('Ongeza Marekebisho - ${widget.month}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_failure != null) FormNotice(_failure!),
                    Autocomplete<Employee>(
                      displayStringForOption: (e) => '${e.fullName} (${e.id})',
                      optionsBuilder: (value) {
                        final q = value.text.trim().toLowerCase();
                        return employees.where((e) => q.isEmpty || e.fullName.toLowerCase().contains(q) || e.id.toLowerCase().contains(q)).take(8);
                      },
                      onSelected: (e) => setState(() {
                        _employee = e;
                        _errors.remove('employee');
                      }),
                      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                        controller: controller,
                        focusNode: focus,
                        autofocus: true,
                        onChanged: (_) => _employee = null,
                        decoration: InputDecoration(
                          labelText: tr('Mfanyakazi *'),
                          hintText: tr('Andika jina au namba...'),
                          prefixIcon: const Icon(Icons.person_search_outlined, size: 18),
                          errorText: _errors['employee'] == null ? null : tr(_errors['employee']!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppDropdown<String>(
                      label: 'Aina ya Marekebisho',
                      value: _kind,
                      items: _PayrollAdjustmentsScreenState._kinds,
                      labelOf: (k) => _PayrollAdjustmentsScreenState._kindNames[k] ?? k,
                      required: true,
                      onChanged: (v) => setState(() => _kind = v ?? _kind),
                    ),
                    const SizedBox(height: 14),
                    if (_isLeave)
                      AppTextField(
                        label: 'Siku za likizo bila malipo',
                        controller: _days,
                        required: true,
                        icon: Icons.event_busy_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
                        helper: 'Mshahara wa msingi unapunguzwa kwa siku hizi KABLA ya kodi na pensheni.',
                        errorText: _errors['days'],
                        onChanged: (_) => setState(() => _errors.remove('days')),
                      )
                    else
                      AppTextField(
                        label: 'Kiasi (TZS)',
                        controller: _amount,
                        required: true,
                        icon: Icons.attach_money,
                        prefixText: 'TZS ',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,3}'))],
                        errorText: _errors['amount'],
                        onChanged: (_) => setState(() => _errors.remove('amount')),
                      ),
                    const SizedBox(height: 14),
                    AppTextField(label: 'Maelezo (hiari)', controller: _description, icon: Icons.notes_outlined, textCapitalization: TextCapitalization.sentences),
                    if (_isEarning)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Inatozwa Kodi (PAYE)', style: TextStyle(fontSize: 12.5)),
                        subtitle: Text(_taxable ? 'Inaingia kwenye mapato yanayotozwa kodi.' : 'Inaongezwa baada ya kodi.', style: TextStyle(fontSize: 10.5, color: Pal.textMuted)),
                        value: _taxable,
                        onChanged: (v) => setState(() => _taxable = v),
                      ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
            FormActions(
              onCancel: () => Navigator.of(context).pop(false),
              onSubmit: _save,
              busy: _saving,
              submitLabel: 'Ongeza',
            ),
          ],
        ),
      ),
    );
  }
}
