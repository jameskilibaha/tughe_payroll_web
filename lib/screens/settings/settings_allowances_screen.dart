import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/allowances_settings_controller.dart';
import '../../models/master_allowance_setting.dart';
import '../../utils/formatters.dart';
import '../widgets/responsive_header_bar.dart';
import '../widgets/app_status_views.dart';

const _green = Color(0xFF15803D);

class SettingsAllowancesScreen extends StatelessWidget {
  const SettingsAllowancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AllowancesSettingsController>();

    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveHeaderBar(
              title: const Text('MASTER SETTINGS: NYONGEZA (ALLOWANCES)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _green)),
              subtitle: const Text(
                'Simamia orodha kuu ya posho (allowances) zitakazotumika kuwapangia '
                'wafanyakazi — asilimia au kiwango, aina ya posho, na kama ni kwa kila mtu.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              actions: [
                ElevatedButton.icon(
                  onPressed: () => _openForm(context, ctrl, null),
                  style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ongeza Posho', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ctrl.isLoading.value
                  ? const AppLoadingIndicator(message: 'Inapakua mipangilio ya posho...')
                  : (ctrl.errorMessage.value.isNotEmpty && ctrl.masterAllowances.isEmpty)
                      ? AppErrorRetryView(message: ctrl.errorMessage.value, onRetry: ctrl.refreshFromBackend)
                      : ctrl.masterAllowances.isEmpty
                          ? const Center(
                              child: Text('Hakuna mipangilio ya posho bado.', style: TextStyle(color: Colors.black45)))
                          : ListView.separated(
                              itemCount: ctrl.masterAllowances.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final m = ctrl.masterAllowances[i];
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
                                                    BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                                                child: Text(m.allowanceType, style: TextStyle(fontSize: 9.5, color: Colors.green.shade800)),
                                              ),
                                              if (m.isForEveryone) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                      color: Colors.amber.shade50, borderRadius: BorderRadius.circular(4)),
                                                  child: const Text('Kila Mtu', style: TextStyle(fontSize: 9.5, color: Colors.amber)),
                                                ),
                                              ],
                                            ]),
                                            const SizedBox(height: 4),
                                            Text(
                                              m.additionType == 'Percent' ? '${m.defaultValue}%' : formatTZS(m.defaultValue),
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

  void _openForm(BuildContext context, AllowancesSettingsController ctrl, MasterAllowanceSetting? existing) {
    showDialog(context: context, builder: (_) => _AllowanceFormDialog(ctrl: ctrl, existing: existing));
  }

  Future<void> _confirmSync(BuildContext context, AllowancesSettingsController ctrl, MasterAllowanceSetting m) async {
    final valueLabel = m.additionType == 'Percent' ? '${m.defaultValue}%' : formatTZS(m.defaultValue);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sasisha Thamani kwa Wote'),
        content: Text(
            'Hii itasasisha thamani ya "${m.name}" ($valueLabel) kwa wafanyakazi WOTE walioshakupewa posho hili tayari, kabla ya kuendesha payroll. Endelea?'),
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

class _AllowanceFormDialog extends StatefulWidget {
  const _AllowanceFormDialog({required this.ctrl, this.existing});
  final AllowancesSettingsController ctrl;
  final MasterAllowanceSetting? existing;

  @override
  State<_AllowanceFormDialog> createState() => _AllowanceFormDialogState();
}

class _AllowanceFormDialogState extends State<_AllowanceFormDialog> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _valueCtrl = TextEditingController(text: widget.existing?.defaultValue.toStringAsFixed(0) ?? '0');
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  String _allowanceType = 'Special';
  String _additionType = 'Percent';
  bool _isForEveryone = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _allowanceType = e?.allowanceType ?? 'Special';
    _additionType = e?.additionType ?? 'Percent';
    _isForEveryone = e?.isForEveryone ?? true;
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final setting = MasterAllowanceSetting(
      id: widget.existing?.id ?? widget.ctrl.generateNextId(),
      name: _nameCtrl.text.trim(),
      allowanceType: _allowanceType,
      additionType: _additionType,
      defaultValue: double.tryParse(_valueCtrl.text) ?? 0,
      isForEveryone: _isForEveryone,
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
                Text(widget.existing == null ? 'Ongeza Posho Mpya' : 'Hariri Posho',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _green)),
                const SizedBox(height: 12),
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Jina la Posho', isDense: true)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _allowanceType,
                      decoration: const InputDecoration(labelText: 'Aina ya Posho', isDense: true),
                      items: const ['Special', 'Other']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 11))))
                          .toList(),
                      onChanged: (v) => setState(() => _allowanceType = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _additionType,
                      decoration: const InputDecoration(labelText: 'Aina ya Nyongeza', isDense: true),
                      items: const ['Amount', 'Percent']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 11))))
                          .toList(),
                      onChanged: (v) => setState(() => _additionType = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: _valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Kiwango Chaguo-msingi (Default Value)', isDense: true),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kwa Kila Mtu (For Everyone)', style: TextStyle(fontSize: 12)),
                  value: _isForEveryone,
                  onChanged: (v) => setState(() => _isForEveryone = v),
                ),
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
                      style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
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
