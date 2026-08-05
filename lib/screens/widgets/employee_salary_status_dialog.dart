import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/employee_controller.dart';
import '../../models/employee.dart';
import '../../models/salary_status.dart';
import '../../utils/formatters.dart';
import 'modal_header_banner.dart';

// Matches the original EmployeeSalaryStatusModal.tsx: blue-900 to indigo-900
// gradient header.
const _blue900 = Color(0xFF1E3A8A);
const _indigo900 = Color(0xFF312E81);
const _blue50 = Color(0xFFEFF6FF);

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
      TextEditingController(text: widget.employee.salaryStatus?.basicSalary.toStringAsFixed(0) ?? '');
  late final _bankAccountCtrl =
      TextEditingController(text: widget.employee.salaryStatus?.bankAccountNumber ?? '');
  String _bankName = 'NMB Bank';

  final _banks = const ['NMB Bank', 'CRDB Bank', 'NBC Bank', 'Equity Bank', 'Exim Bank', 'DTB Bank'];

  @override
  void initState() {
    super.initState();
    _bankName = widget.employee.salaryStatus?.bankName ?? _banks.first;
  }

  bool _isSaving = false;

  Future<void> _save() async {
    final basicSalary = double.tryParse(_basicSalaryCtrl.text.trim()) ?? 0;
    final status = SalaryStatus(
      occupation: _occupationCtrl.text.trim(),
      workStation: _workStationCtrl.text.trim(),
      basicSalary: basicSalary,
      bankName: _bankName,
      bankAccountNumber: _bankAccountCtrl.text.trim(),
    );
    setState(() => _isSaving = true);
    await Get.find<EmployeeController>().saveSalaryStatus(widget.employee.id, status);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _blue900, width: 1.5)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
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
                        color: _blue50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _blue900.withOpacity(0.2)),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 11, color: _blue900),
                          children: [
                            const TextSpan(text: 'Mfanyakazi: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: '${widget.employee.fullName} (${widget.employee.id})'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _occupationCtrl,
                      decoration: const InputDecoration(labelText: 'Wadhifa / Cheo (Occupation)', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _workStationCtrl,
                      decoration: const InputDecoration(labelText: 'Kituo cha Kazi (Work Station)', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _basicSalaryCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Mshahara wa Msingi (Basic Salary - TZS)', isDense: true),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _banks.contains(_bankName) ? _bankName : _banks.first,
                      decoration: const InputDecoration(labelText: 'Benki (Bank)', isDense: true),
                      items: _banks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (v) => setState(() => _bankName = v ?? _bankName),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bankAccountCtrl,
                      decoration: const InputDecoration(labelText: 'Namba ya Akaunti ya Benki', isDense: true),
                    ),
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
                    style: ElevatedButton.styleFrom(backgroundColor: _blue900, foregroundColor: Colors.white),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Hifadhi'),
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
