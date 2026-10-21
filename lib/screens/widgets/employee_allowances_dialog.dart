import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../../controllers/allowances_settings_controller.dart';
import '../../controllers/employee_controller.dart';
import '../../models/assigned_allowance.dart';
import '../../models/employee.dart';
import '../../utils/formatters.dart';
import 'modal_header_banner.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';
import '../../core/tr_snack.dart';
import '../../core/theme.dart';

// Matches the original EmployeeAllowancesModal.tsx: purple/indigo gradient
// header with a purple-600 dialog border (not green).
const _purple900 = Color(0xFF581C87);
const _indigo950 = Color(0xFF1E1B4B);
const _purple600 = Color(0xFF9333EA);
const _purple50 = Color(0xFFFAF5FF);

Future<void> showAllowancesDialog(BuildContext context, Employee employee) {
  return showDialog(context: context, builder: (_) => _AllowancesDialog(employee: employee));
}

class _AllowancesDialog extends StatefulWidget {
  const _AllowancesDialog({required this.employee});
  final Employee employee;

  @override
  State<_AllowancesDialog> createState() => _AllowancesDialogState();
}

class _AllowancesDialogState extends State<_AllowancesDialog> {
  late List<AssignedAllowance> _allowances = List.of(widget.employee.allowancesList ?? []);

  String? _selectedMasterId;
  final _nameCtrl = TextEditingController();
  final _valueCtrl = TextEditingController(text: '15');
  String _additionType = 'Percent';
  bool _isSpecial = false;

  double get _basicSalary => widget.employee.salaryStatus?.basicSalary ?? 0;

  void _applyMasterSetting(String settingId) {
    final matches =
        Get.find<AllowancesSettingsController>().masterAllowances.where((m) => m.id == settingId);
    if (matches.isEmpty) return;
    final master = matches.first;
    setState(() {
      _selectedMasterId = settingId;
      _nameCtrl.text = master.name;
      _additionType = master.additionType;
      _valueCtrl.text = plainAmount(master.defaultValue);
      _isSpecial = master.allowanceType == 'Special';
    });
  }

  /// Adds whatever is currently in the "add" form to the list. Returns
  /// true if something was added, false if the name field was empty.
  bool _addAllowance() {
    if (_nameCtrl.text.trim().isEmpty) return false;
    final item = AssignedAllowance(
      id: 'ALW-${DateTime.now().millisecondsSinceEpoch}',
      settingId: _selectedMasterId,
      name: _nameCtrl.text.trim(),
      additionType: _additionType,
      value: double.tryParse(_valueCtrl.text) ?? 0,
      isSpecial: _isSpecial,
    );
    setState(() {
      _allowances = [..._allowances, item];
      _selectedMasterId = null;
      _nameCtrl.clear();
      _valueCtrl.text = '15';
      _isSpecial = false;
      _additionType = 'Percent';
    });
    return true;
  }

  void _removeAllowance(String id) {
    setState(() => _allowances = _allowances.where((a) => a.id != id).toList());
  }

  Future<void> _deleteNow(AssignedAllowance allowance) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Futa Kabisa Sasa'),
        content: Text(
            'Hii itafuta "${allowance.name}" moja kwa moja kwenye seva SASA HIVI (siyo kusubiri "Hifadhi"). Endelea?'),
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
    await Get.find<EmployeeController>().deleteAllowanceNow(widget.employee.id, allowance);
    setState(() => _allowances = _allowances.where((a) => a.id != allowance.id).toList());
  }

  bool _isSaving = false;

  Future<void> _save() async {
    // If the person filled in the "add" form but forgot to press "Ongeza
    // Posho" first, add it for them automatically - this is the single
    // most common way to lose what you just typed.
    final hadPendingEntry = _nameCtrl.text.trim().isNotEmpty;
    if (hadPendingEntry) _addAllowance();

    if (_allowances.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Hakuna Posho Lolote'),
          content: const Text(
              'Hujaweka posho lolote kwa mfanyakazi huyu. Je, unataka kuendelea kuhifadhi (hii itafuta posho zote zilizokuwepo awali)?'),
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
    await Get.find<EmployeeController>().saveAllowances(widget.employee.id, _allowances);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final masterAllowances = Get.find<AllowancesSettingsController>().masterAllowances;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _purple600, width: 2)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModalHeaderBanner(
              icon: Icons.card_giftcard,
              title: 'Form ya Employee Allowances (Posho za Mfanyakazi)',
              subtitle: 'Ongeza Posho za Nyongeza kwa Percent na Nyongeza kwa Amount kwa ${widget.employee.fullName}',
              gradientColors: const [_purple900, _purple900, _indigo950],
              iconColor: Colors.purple.shade200,
              subtitleColor: Colors.purple.shade200,
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
                        color: _purple50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _purple600.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: TextStyle(fontSize: 11, color: _purple900),
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
                              style: TextStyle(fontSize: 11, color: _purple900),
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
                            Icon(Icons.add, size: 15, color: _purple900),
                            const SizedBox(width: 6),
                            const Text('ONGEZA POSHO JIPYA (ADD ALLOWANCE)',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                          ]),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedMasterId,
                            decoration: InputDecoration(
                                labelText: tr('Chagua kutoka Mipangilio Mikuu (Master Allowances)'), isDense: true),
                            items: masterAllowances
                                .map((m) => DropdownMenuItem(
                                    value: m.id,
                                    child: Text(
                                        '${m.name} (${m.additionType == "Percent" ? "${m.defaultValue}%" : formatTZS(m.defaultValue)})',
                                        style: const TextStyle(fontSize: 11))))
                                .toList(),
                            onChanged: (v) => v != null ? _applyMasterSetting(v) : null,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                                labelText: tr('Jina la Posho / Allowance Name *'),
                                hintText: tr('e.g. Posho ya Nyumba, Posho ya Usafiri'),
                                isDense: true),
                          ),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _additionType,
                                decoration: InputDecoration(labelText: tr('Aina ya Nyongeza'), isDense: true),
                                items: const [
                                  DropdownMenuItem(value: 'Percent', child: Text('Nyongeza kwa Percent (%)', style: TextStyle(fontSize: 11))),
                                  DropdownMenuItem(value: 'Amount', child: Text('Nyongeza kwa Amount (TZS)', style: TextStyle(fontSize: 11))),
                                ],
                                onChanged: (v) => setState(() => _additionType = v!),
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
                            activeColor: _purple600,
                            title: const Text('Posho Maalum (Special)', style: TextStyle(fontSize: 11.5)),
                            value: _isSpecial,
                            onChanged: (v) => setState(() => _isSpecial = v),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final added = _addAllowance();
                                if (!added) {
                                  trSnack('Jina Linahitajika', 'Tafadhali jaza "Jina la Posho" kwanza.');
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: _purple600, foregroundColor: Colors.white),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Ongeza Posho', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Posho Zilizowekwa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    if (_allowances.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text('Hakuna posho zilizowekwa bado.', style: TextStyle(color: Pal.textMuted, fontSize: 11)),
                      )
                    else
                      ..._allowances.map((a) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _purple50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _purple600.withOpacity(0.25)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.card_giftcard, size: 14, color: _purple600),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                        if (a.isSpecial) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(color: _purple600, borderRadius: BorderRadius.circular(4)),
                                            child: const Text('SPECIAL',
                                                style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ]),
                                      Text(
                                        a.additionType == 'Percent' ? '${a.value}%' : formatTZS(a.value),
                                        style: TextStyle(fontSize: 10.5, color: _purple900.withOpacity(0.8)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: tr('Ondoa Kwenye Orodha (itafutwa seva ukibonyeza Hifadhi)'),
                                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.orange),
                                  onPressed: () => _removeAllowance(a.id),
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
                    style: ElevatedButton.styleFrom(backgroundColor: _purple600, foregroundColor: Colors.white),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Hifadhi Posho'),
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
