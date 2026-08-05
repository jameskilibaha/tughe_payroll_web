import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/arrears_settings_controller.dart';
import '../../models/master_arrear_setting.dart';
import '../../utils/formatters.dart';
import '../widgets/responsive_header_bar.dart';
import '../widgets/app_status_views.dart';

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
              title: const Text('MASTER SETTINGS: MAKATO (ARREARS)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _brandBlue)),
              subtitle: const Text(
                'Simamia orodha kuu ya makato (arrears/deductions) yatakayotumika '
                'kuwapangia wafanyakazi — asilimia au kiwango, aina ya kato, na marudio.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              actions: [
                ElevatedButton.icon(
                  onPressed: () => _openForm(context, ctrl, null),
                  style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
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
                          ? const Center(
                              child: Text('Hakuna mipangilio ya makato bado.', style: TextStyle(color: Colors.black45)))
                          : ListView.separated(
                              itemCount: ctrl.masterArrears.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final m = ctrl.masterArrears[i];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                                    BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                                child: Text(m.arrearsType, style: const TextStyle(fontSize: 9.5, color: _brandBlue)),
                                              ),
                                            ]),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${m.deductionType == 'Percent' ? '${m.defaultValue}%' : formatTZS(m.defaultValue)} • ${m.isCreditOrDebit} • ${m.frequency}',
                                              style: const TextStyle(fontSize: 10.5, color: Colors.black54),
                                            ),
                                            if (m.description != null && m.description!.isNotEmpty)
                                              Text(m.description!, style: const TextStyle(fontSize: 10, color: Colors.black45)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Sasisha kwa Wafanyakazi Wote (Sync)',
                                        icon: Icon(Icons.sync, size: 18, color: Colors.blue.shade700),
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
  late final _valueCtrl = TextEditingController(text: widget.existing?.defaultValue.toStringAsFixed(0) ?? '0');
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  String _arrearsType = 'Special';
  String _deductionType = 'Percent';
  String _creditOrDebit = 'Debit';
  String _frequency = 'Always';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _arrearsType = e?.arrearsType ?? 'Special';
    _deductionType = e?.deductionType ?? 'Percent';
    _creditOrDebit = e?.isCreditOrDebit ?? 'Debit';
    _frequency = e?.frequency ?? 'Always';
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final setting = MasterArrearSetting(
      id: widget.existing?.id ?? widget.ctrl.generateNextId(),
      name: _nameCtrl.text.trim(),
      arrearsType: _arrearsType,
      deductionType: _deductionType,
      defaultValue: double.tryParse(_valueCtrl.text) ?? 0,
      isCreditOrDebit: _creditOrDebit,
      frequency: _frequency,
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
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _brandBlue)),
                const SizedBox(height: 12),
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Jina la Kato', isDense: true)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _arrearsType,
                      decoration: const InputDecoration(labelText: 'Aina ya Kato', isDense: true),
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
                      decoration: const InputDecoration(labelText: 'Aina ya Deduction', isDense: true),
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
                  decoration: const InputDecoration(labelText: 'Kiwango Chaguo-msingi (Default Value)', isDense: true),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _creditOrDebit,
                      decoration: const InputDecoration(labelText: 'Credit/Debit', isDense: true),
                      items: const ['Credit', 'Debit']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 11))))
                          .toList(),
                      onChanged: (v) => setState(() => _creditOrDebit = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _frequency,
                      decoration: const InputDecoration(labelText: 'Marudio (Frequency)', isDense: true),
                      items: const ['Always', 'Ones']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 11))))
                          .toList(),
                      onChanged: (v) => setState(() => _frequency = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Maelezo (Description)', isDense: true),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Ghairi')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
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
