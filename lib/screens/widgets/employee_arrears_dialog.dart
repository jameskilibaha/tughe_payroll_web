import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../../controllers/arrears_settings_controller.dart';
import '../../controllers/employee_controller.dart';
import '../../models/assigned_arrear.dart';
import '../../models/employee.dart';
import '../../utils/formatters.dart';
import 'modal_header_banner.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';
import '../../core/tr_snack.dart';
import '../../core/theme.dart';

// Matches the original EmployeeArrearsModal.tsx: amber gradient header with
// an amber-500 dialog border.
const _amber700 = Color(0xFFB45309);
const _amber900 = Color(0xFF78350F);
const _amber500 = Color(0xFFF59E0B);
const _amber50 = Color(0xFFFFFBEB);

Future<void> showArrearsDialog(BuildContext context, Employee employee) {
  return showDialog(context: context, builder: (_) => _ArrearsDialog(employee: employee));
}

class _ArrearsDialog extends StatefulWidget {
  const _ArrearsDialog({required this.employee});
  final Employee employee;

  @override
  State<_ArrearsDialog> createState() => _ArrearsDialogState();
}

class _ArrearsDialogState extends State<_ArrearsDialog> {
  late List<AssignedArrear> _arrears = List.of(widget.employee.arrearsList ?? []);

  String? _selectedMasterId;
  final _nameCtrl = TextEditingController();
  final _valueCtrl = TextEditingController(text: '2');
  final _totalDebtCtrl = TextEditingController(text: '');
  String _deductionType = 'Percent';
  String _frequency = 'Always';
  String _creditOrDebit = 'Debit';
  bool _isDebtReduction = false;

  double get _basicSalary => widget.employee.salaryStatus?.basicSalary ?? 0;

  /// The chosen master arrear is "Credit & Debit" (a debt): debt mode is on and cannot be switched off.
  bool _masterIsDebt = false;

  void _applyMasterSetting(String settingId) {
    final matches = Get.find<ArrearsSettingsController>().masterArrears.where((m) => m.id == settingId);
    if (matches.isEmpty) return;
    final master = matches.first;
    setState(() {
      _selectedMasterId = settingId;
      _nameCtrl.text = master.name;
      _deductionType = master.deductionType;
      _valueCtrl.text = plainAmount(master.defaultValue);
      _frequency = master.frequencyLabel;
      _creditOrDebit = master.creditDebitLabel;
      // "Credit & Debit" means a DEBT: deducted every month until it is paid in full, then removed.
      _masterIsDebt = master.isPermanentDeduction;
      final lower = master.name.toLowerCase();
      _isDebtReduction = _masterIsDebt || lower.contains('deni') || lower.contains('mkopo');
      if (_isDebtReduction) {
        _deductionType = 'Amount'; // a debt is repaid with a fixed amount every month
        _totalDebtCtrl.text = '';
      }
    });
  }

  /// Adds whatever is currently in the "add" form to the list. Returns
  /// true if something was added, false if the name field was empty (so
  /// [_save] can tell the difference between "nothing to add" and "added
  /// successfully").
  bool _addArrear() {
    if (_nameCtrl.text.trim().isEmpty) return false;
    final totalDebt = double.tryParse(_totalDebtCtrl.text.trim()) ?? 0;
    if (_isDebtReduction && totalDebt <= 0) {
      trSnack('Jumla ya Deni', 'Weka Jumla ya Deni (zaidi ya 0) kabla ya kuliongeza.');
      return false;
    }
    final item = AssignedArrear(
      id: 'ARR-${DateTime.now().millisecondsSinceEpoch}',
      settingId: _selectedMasterId,
      name: _nameCtrl.text.trim(),
      deductionType: _deductionType,
      value: double.tryParse(_valueCtrl.text) ?? 0,
      isDebtReduction: _isDebtReduction,
      totalDebtAmount: _isDebtReduction ? totalDebt : null,
      remainingDebtAmount: _isDebtReduction ? totalDebt : null, // a new debt: nothing paid yet
      frequency: _frequency,
      isCreditOrDebit: _creditOrDebit,
    );
    setState(() {
      _arrears = [..._arrears, item];
      _selectedMasterId = null;
      _nameCtrl.clear();
      _valueCtrl.text = '2';
      _isDebtReduction = false;
      _totalDebtCtrl.clear();
      _deductionType = 'Percent';
    });
    return true;
  }

  void _removeArrear(String id) {
    setState(() => _arrears = _arrears.where((a) => a.id != id).toList());
  }

  Future<void> _deleteNow(AssignedArrear arrear) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Futa Kabisa Sasa'),
        content: Text(
            'Hii itafuta "${arrear.name}" moja kwa moja kwenye seva SASA HIVI (siyo kusubiri "Hifadhi"). Endelea?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Ghairi')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ndiyo, Futa Kabisa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Get.find<EmployeeController>().deleteArrearNow(widget.employee.id, arrear);
    setState(() => _arrears = _arrears.where((a) => a.id != arrear.id).toList());
  }

  bool _isSaving = false;

  Future<void> _save() async {
    // If the person filled in the "add" form but forgot to press "Ongeza
    // Kato" first, add it for them automatically instead of silently
    // saving without it - this is the single most common way to lose
    // what you just typed.
    final hadPendingEntry = _nameCtrl.text.trim().isNotEmpty;
    if (hadPendingEntry) _addArrear();

    if (_arrears.isEmpty) {
      // Saving a genuinely empty list is valid (clearing all assignments
      // on purpose), but if there's truly nothing here at all, a gentle
      // check avoids an accidental no-op save.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Hakuna Kato Lolote'),
          content: const Text(
              'Hujaweka kato lolote kwa mfanyakazi huyu. Je, unataka kuendelea kuhifadhi (hii itafuta makato yote yaliyokuwepo awali)?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Rudi Nyuma')),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ndiyo, Hifadhi'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isSaving = true);
    await Get.find<EmployeeController>().saveArrears(widget.employee.id, _arrears);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final masterArrears = Get.find<ArrearsSettingsController>().masterArrears;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _amber500, width: 2)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModalHeaderBanner(
              icon: Icons.trending_down,
              title: 'Form ya Employee Arrears (Makato ya Mfanyakazi)',
              subtitle:
                  'Weka makato ya Percent, Makato ya Amount, na Makato ya Kupunguza Deni kwa ${widget.employee.fullName}',
              gradientColors: const [_amber700, _amber700, _amber900],
              iconColor: Colors.amber.shade200,
              subtitleColor: Colors.amber.shade100,
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _amber50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _amber500.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: TextStyle(fontSize: 11, color: _amber900),
                                children: [
                                  TextSpan(text: tr('Mfanyakazi: '), style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: '${widget.employee.fullName} (${widget.employee.id})'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 11, color: _amber900),
                              children: [
                                TextSpan(text: tr('Mshahara Msingi: '), style: TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: formatTZS(_basicSalary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Pal.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Icon(Icons.add, size: 15, color: _amber900),
                            const SizedBox(width: 6),
                            const Text('ONGEZA KATO JIPYA (ADD ARREAR)',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                          ]),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedMasterId,
                            decoration: InputDecoration(
                                labelText: tr('Chagua kutoka Mipangilio Mikuu (Master Arrears)'), isDense: true),
                            items: masterArrears
                                .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name, style: const TextStyle(fontSize: 11))))
                                .toList(),
                            onChanged: (v) => v != null ? _applyMasterSetting(v) : null,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(labelText: tr('Jina la Kato *'), isDense: true),
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _deductionType,
                                decoration: InputDecoration(labelText: tr('Aina'), isDense: true),
                                items: const ['Amount', 'Percent', 'Nothing']
                                    .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 11))))
                                    .toList(),
                                onChanged: (v) => setState(() => _deductionType = v!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _valueCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: tr('Kiwango'), isDense: true),
                              ),
                            ),
                          ]),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: _amber500,
                            title: const Text('Kato la Kupunguza Deni (Debt Reduction)', style: TextStyle(fontSize: 11.5)),
                            value: _isDebtReduction,
                            onChanged: _masterIsDebt
                                ? null
                                : (v) => setState(() {
                                      _isDebtReduction = v;
                                      if (v) _deductionType = 'Amount';
                                    }),
                          ),
                          if (_masterIsDebt)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Credit & Debit = DENI: linakatwa kila mwezi hadi lilipwe lote. Likiisha, makato yanaondolewa yenyewe kwa mfanyakazi huyu.',
                                style: TextStyle(fontSize: 10.5, color: Pal.textSecondary),
                              ),
                            ),
                          if (_isDebtReduction)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _totalDebtCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(labelText: tr('Jumla ya Deni'), isDense: true),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InputDecorator(
                                        decoration: InputDecoration(labelText: tr('Deni Lililobaki'), isDense: true),
                                        child: Text(
                                          formatTZS(double.tryParse(_totalDebtCtrl.text.trim()) ?? 0),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Kiwango hapo juu ndicho kato la kila mwezi. Makato yanasimama yenyewe deni likiisha - kamwe hayashuki chini ya 0.',
                                    style: TextStyle(fontSize: 10, color: Colors.black45),
                                  ),
                                ],
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final added = _addArrear();
                                if (!added) {
                                  trSnack('Jina Linahitajika', 'Tafadhali jaza "Jina la Kato" kwanza.');
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: _amber700, foregroundColor: Colors.white),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Ongeza Kato', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Makato Yaliyowekwa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    if (_arrears.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text('Hakuna makato yaliyowekwa bado.', style: TextStyle(color: Pal.textMuted, fontSize: 11)),
                      )
                    else
                      ..._arrears.map((a) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _amber50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _amber500.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.trending_down, size: 14, color: _amber700),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                        if (a.isDebtReduction) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(color: _amber700, borderRadius: BorderRadius.circular(4)),
                                            child: const Text('DEBT',
                                                style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ]),
                                      Text(
                                        a.deductionType == 'Percent' ? '${a.value}%' : formatTZS(a.value),
                                        style: TextStyle(fontSize: 10.5, color: _amber900.withOpacity(0.85)),
                                      ),
                                      if (a.needsTotal)
                                        Text('Deni hili halina Jumla ya Deni - ondoa na uliweke tena na jumla ili makato yasimame yenyewe likiisha.',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                                      if (a.isDebtReduction && a.totalDebtAmount != null)
                                        Text('Jumla ya Deni: ${formatTZS(a.totalDebtAmount!)}',
                                            style: TextStyle(fontSize: 10, color: Pal.textSecondary)),
                                      if (a.isDebtReduction && a.remainingDebtAmount != null)
                                        Text(
                                          a.remainingDebtAmount! <= 0
                                              ? 'Deni limelipwa kikamilifu - hakuna makato yanayoendelea'
                                              : 'Deni Lililobaki: ${formatTZS(a.remainingDebtAmount!)}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: a.remainingDebtAmount! <= 0 ? Colors.green.shade700 : Colors.deepOrange),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: tr('Ondoa Kwenye Orodha (itafutwa seva ukibonyeza Hifadhi)'),
                                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.orange),
                                  onPressed: () => _removeArrear(a.id),
                                ),
                                IconButton(
                                  tooltip: tr('Futa Kabisa Sasa (moja kwa moja kwenye seva)'),
                                  icon: const Icon(Icons.delete_forever, size: 18, color: Colors.red),
                                  onPressed: () => _deleteNow(a),
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Ghairi')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: _amber700, foregroundColor: Colors.white),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Hifadhi Makato'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
