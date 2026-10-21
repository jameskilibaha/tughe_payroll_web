import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../../controllers/arrears_settings_controller.dart';
import '../../models/master_arrear_setting.dart';
import '../../utils/formatters.dart';
import '../widgets/responsive_header_bar.dart';
import '../widgets/app_status_views.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';
import '../../core/theme.dart';

const _brandBlue = Color(0xFF1E3A8A);

class SettingsArrearsScreen extends StatelessWidget {
  const SettingsArrearsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ArrearsSettingsController>();

    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveHeaderBar(
              title: Text('MASTER SETTINGS: MAKATO (ARREARS)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Pal.brandText)),
              subtitle: Text(
                'Simamia orodha kuu ya makato (arrears/deductions) yatakayotumika '
                'kuwapangia wafanyakazi — asilimia au kiwango, aina ya kato, na marudio.',
                style: TextStyle(fontSize: 11, color: Pal.textSecondary),
              ),
              actions: [
                ElevatedButton.icon(
                  onPressed: () => _openForm(context, ctrl, null),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ongeza Kato', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ctrl.isLoading.value
                  ? const AppLoadingIndicator(message: 'Inapakua mipangilio ya makato...')
                  : (ctrl.errorMessage.value.isNotEmpty && ctrl.masterArrears.isEmpty)
                      ? AppErrorRetryView(message: ctrl.errorMessage.value, onRetry: ctrl.refreshFromBackend)
                      : ctrl.masterArrears.isEmpty
                          ? Center(
                              child: Text('Hakuna mipangilio ya makato bado.', style: TextStyle(color: Pal.textMuted)))
                          : ListView.separated(
                              itemCount: ctrl.masterArrears.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final m = ctrl.masterArrears[i];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Pal.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Pal.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration:
                                                    BoxDecoration(color: Pal.tint(Colors.blue), borderRadius: BorderRadius.circular(4)),
                                                child: Text(m.arrearsType, style: TextStyle(fontSize: 9.5, color: Pal.brandText)),
                                              ),
                                            ]),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${m.deductionType == 'Percent' ? '${m.defaultValue}%' : formatTZS(m.defaultValue)} • ${m.creditDebitLabel} • ${m.frequencyLabel}',
                                              style: TextStyle(fontSize: 10.5, color: Pal.textSecondary),
                                            ),
                                            if (m.description != null && m.description!.isNotEmpty)
                                              Text(m.description!, style: TextStyle(fontSize: 10, color: Pal.textMuted)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: tr('Sasisha kwa Wafanyakazi Wote (Sync)'),
                                        icon: Icon(Icons.sync, size: 18, color: Pal.fg(Colors.blue.shade700)),
                                        onPressed: () => _confirmSync(context, ctrl, m),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        onPressed: () => _openForm(context, ctrl, m),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        onPressed: () => ctrl.deleteSetting(m.id),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ));
  }

  void _openForm(BuildContext context, ArrearsSettingsController ctrl, MasterArrearSetting? existing) {
    showDialog(context: context, builder: (_) => _ArrearFormDialog(ctrl: ctrl, existing: existing));
  }

  Future<void> _confirmSync(BuildContext context, ArrearsSettingsController ctrl, MasterArrearSetting m) async {
    final valueLabel = m.deductionType == 'Percent' ? '${m.defaultValue}%' : formatTZS(m.defaultValue);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sasisha Thamani kwa Wote'),
        content: Text(
            'Hii itasasisha thamani ya "${m.name}" ($valueLabel) kwa wafanyakazi WOTE walioshakupewa kato hili tayari, kabla ya kuendesha payroll. Endelea?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Ghairi')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ndiyo, Sasisha'),
          ),
        ],
      ),
    );
    if (ok == true) await ctrl.syncSettingToEmployees(m);
  }
}

class _ArrearFormDialog extends StatefulWidget {
  const _ArrearFormDialog({required this.ctrl, this.existing});
  final ArrearsSettingsController ctrl;
  final MasterArrearSetting? existing;

  @override
  State<_ArrearFormDialog> createState() => _ArrearFormDialogState();
}

class _ArrearFormDialogState extends State<_ArrearFormDialog> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _valueCtrl = TextEditingController(text: plainAmount(widget.existing?.defaultValue ?? 0));
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  String _arrearsType = 'Special';
  String _deductionType = 'Percent';
  bool _isPermanentDeduction = false;
  bool _isChoice = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _arrearsType = e?.arrearsType ?? 'Special';
    _deductionType = e?.deductionType ?? 'Percent';
    _isPermanentDeduction = e?.isPermanentDeduction ?? false;
    _isChoice = e?.isChoice ?? true;
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final setting = MasterArrearSetting(
      id: widget.existing?.id ?? widget.ctrl.generateNextId(),
      name: _nameCtrl.text.trim(),
      arrearsType: _arrearsType,
      deductionType: _deductionType,
      defaultValue: double.tryParse(_valueCtrl.text) ?? 0,
      isPermanentDeduction: _isPermanentDeduction,
      isChoice: _isChoice,
      description: _descCtrl.text.trim(),
      backendId: widget.existing?.backendId,
    );
    widget.ctrl.saveSetting(setting);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.existing == null ? 'Ongeza Kato Jipya' : 'Hariri Kato',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Pal.brandText)),
                const SizedBox(height: 12),
                TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: tr('Jina la Kato'), isDense: true)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _arrearsType,
                      decoration: InputDecoration(labelText: tr('Aina ya Kato'), isDense: true),
                      items: const ['Special', 'Other']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 11))))
                          .toList(),
                      onChanged: (v) => setState(() => _arrearsType = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _deductionType,
                      decoration: InputDecoration(labelText: tr('Aina ya Deduction'), isDense: true),
                      items: const ['Amount', 'Percent', 'Nothing']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 11))))
                          .toList(),
                      onChanged: (v) => setState(() => _deductionType = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: _valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tr('Kiwango Chaguo-msingi (Default Value)'), isDense: true),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<bool>(
                      value: _isPermanentDeduction,
                      decoration: InputDecoration(labelText: tr('Credit/Debit'), isDense: true),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Credit & Debit', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: false, child: Text('Credit', style: TextStyle(fontSize: 11))),
                      ],
                      onChanged: (v) => setState(() {
                        _isPermanentDeduction = v!;
                        if (v) _deductionType = 'Amount'; // a debt is repaid with a fixed amount each month
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<bool>(
                      value: _isChoice,
                      decoration: InputDecoration(labelText: tr('Marudio (Frequency)'), isDense: true),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Daima (Always)', style: TextStyle(fontSize: 11))),
                        DropdownMenuItem(value: false, child: Text('Mara Moja (Ones)', style: TextStyle(fontSize: 11))),
                      ],
                      onChanged: (v) => setState(() => _isChoice = v!),
                    ),
                  ),
                ]),
                if (_isPermanentDeduction)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Credit & Debit ni DENI: mfanyakazi anakatwa kila mwezi hadi deni lote lilipwe, kisha makato yanaondolewa yenyewe. Weka Jumla ya Deni na kato la mwezi wakati wa kumpa mfanyakazi.',
                      style: TextStyle(fontSize: 10.5, color: Pal.textSecondary),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: tr('Maelezo (Description)'), isDense: true),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Ghairi')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _save,
                      child: const Text('Hifadhi'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
