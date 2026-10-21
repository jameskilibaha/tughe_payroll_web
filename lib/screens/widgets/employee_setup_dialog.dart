import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../../controllers/employee_controller.dart';
import '../../core/theme.dart';
import '../../core/tr_text.dart';
import '../../models/employee.dart';
import 'employee_allowances_dialog.dart';
import 'employee_arrears_dialog.dart';
import 'employee_form_dialog.dart';
import 'employee_salary_status_dialog.dart';

/// "Usajili Kamili": everything about ONE employee, in one list - his details, salary status (basic salary,
/// bank, TIN, pension fund), deductions and allowances. Each step opens the same form as before, and a tick
/// shows what is already filled in. It opens by itself right after a NEW employee is registered, and from the
/// checklist button of any row.
Future<void> showEmployeeSetupDialog(BuildContext context, Employee employee) =>
    showDialog<void>(context: context, builder: (_) => EmployeeSetupDialog(employeeId: employee.id));

class EmployeeSetupDialog extends StatelessWidget {
  const EmployeeSetupDialog({super.key, required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<EmployeeController>();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Obx(() {
          final e = ctrl.employees.firstWhereOrNull((x) => x.id == employeeId);
          if (e == null) {
            return const Padding(padding: EdgeInsets.all(30), child: Text('Mfanyakazi hapatikani.'));
          }
          final hasSalary = e.salaryStatus != null;
          final arrears = e.arrearsList?.length ?? 0;
          final allowances = e.allowancesList?.length ?? 0;
          final needed = 2; // what payroll needs: the details and the salary status
          final doneCount = 1 + (hasSalary ? 1 : 0);

          Widget step({required int n, required String title, required String subtitle, required bool done, required VoidCallback onTap, required String action, bool optional = false}) {
            final color = done ? Colors.green : (optional ? Colors.blueGrey : Colors.orange);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: done ? Pal.fg(Colors.green.shade700).withOpacity(0.5) : Pal.border)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: Pal.tint(color),
                    child: done ? Icon(Icons.check, size: 17, color: Pal.fg(Colors.green.shade700)) : Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Pal.fg(color.shade700))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(child: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800))),
                          if (optional && !done)
                            Padding(padding: const EdgeInsets.only(left: 6), child: Text('(si lazima)', style: TextStyle(fontSize: 10, color: Pal.textMuted))),
                        ]),
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(fontSize: 11, height: 1.3, color: Pal.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  done
                      ? OutlinedButton(onPressed: onTap, child: const Text('Hariri'))
                      : ElevatedButton(onPressed: onTap, child: Text(action)),
                ],
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 14, 4),
                child: Row(children: [
                  Icon(Icons.checklist, color: Pal.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Usajili Kamili wa Mfanyakazi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      Text('${e.fullName}  (${e.id})', style: TextStyle(fontSize: 11.5, color: Pal.textSecondary)),
                    ]),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: doneCount / needed, minHeight: 6)),
                  const SizedBox(height: 6),
                  Text(hasSalary ? 'Mfanyakazi yuko tayari kwa payroll.' : 'Weka hali ya mshahara ili ajumuishwe kwenye payroll.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: hasSalary ? Pal.fg(Colors.green.shade700) : Pal.fg(Colors.orange.shade800))),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
                  child: Column(children: [
                    step(
                      n: 1,
                      title: 'Taarifa za Mfanyakazi',
                      subtitle: 'Majina, jinsia, simu, barua pepe, tarehe ya kuzaliwa na kuajiriwa.',
                      done: true,
                      action: 'Weka',
                      onTap: () => showDialog<String>(context: context, builder: (_) => EmployeeFormDialog(existing: e)),
                    ),
                    step(
                      n: 2,
                      title: 'Hali ya Mshahara',
                      subtitle: hasSalary
                          ? 'Mshahara wa msingi, benki, TIN na mfuko wa pensheni vimewekwa.'
                          : 'Wadhifa, kituo cha kazi, mshahara wa msingi, benki, akaunti, TIN na mfuko wa pensheni.',
                      done: hasSalary,
                      action: 'Weka',
                      onTap: () => showSalaryStatusDialog(context, e),
                    ),
                    step(
                      n: 3,
                      title: 'Makato (Arrears)',
                      subtitle: arrears == 0 ? 'Makato ya kila mwezi, madeni na mikopo.' : 'Makato yaliyowekwa: $arrears.',
                      done: arrears > 0,
                      optional: true,
                      action: 'Weka',
                      onTap: () => showArrearsDialog(context, e),
                    ),
                    step(
                      n: 4,
                      title: 'Posho (Allowances)',
                      subtitle: allowances == 0 ? 'Posho za nyumba, usafiri n.k.' : 'Posho zilizowekwa: $allowances.',
                      done: allowances > 0,
                      optional: true,
                      action: 'Weka',
                      onTap: () => showAllowancesDialog(context, e),
                    ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
                child: Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Maliza'))),
              ),
            ],
          );
        }),
      ),
    );
  }
}
