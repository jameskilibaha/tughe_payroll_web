import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/navigation_controller.dart';
import '../../controllers/salary_terms_controller.dart';
import '../../models/employee.dart';
import '../../utils/formatters.dart';
import '../../utils/payroll_calculator.dart';
import 'employee_salary_status_dialog.dart';
import 'employee_arrears_dialog.dart';
import 'employee_allowances_dialog.dart';

// Matches the original EmployeeDetailModal.tsx: blue-900 via blue-800 to
// indigo-900 gradient header with a big rounded avatar box.
const _brandBlue = Color(0xFF1E3A8A);
const _blue800 = Color(0xFF1E40AF);
const _indigo900 = Color(0xFF312E81);

Future<void> showEmployeeDetailDialog(BuildContext context, Employee employee) {
  return showDialog(context: context, builder: (_) => _EmployeeDetailDialog(employee: employee));
}

class _EmployeeDetailDialog extends StatelessWidget {
  const _EmployeeDetailDialog({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final termsCtrl = Get.find<SalaryTermsController>();
    final calc = calculateEmployeePayroll(employee, traTerms: termsCtrl.traTerms.toList());
    final isBlocked = employee.status == 'Blocked';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_brandBlue, _blue800, _indigo900]),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56, height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade200, width: 2),
                    ),
                    child: Text(
                      '${employee.firstName.isNotEmpty ? employee.firstName[0] : ''}${employee.lastName.isNotEmpty ? employee.lastName[0] : ''}',
                      style: const TextStyle(color: _brandBlue, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(employee.fullName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text(employee.id, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isBlocked ? Colors.red.shade600 : Colors.green.shade600,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(isBlocked ? 'BLOCKED' : 'ACTIVE',
                                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 20, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Taarifa Binafsi'),
                    _kv('Jinsia', employee.gender),
                    _kv('Hali ya Ndoa', employee.maritalStatus),
                    _kv('Uraia', employee.nationality),
                    _kv('Wilaya', employee.residentialDistrict),
                    _kv('Simu', employee.mobileNumber),
                    _kv('Barua Pepe', employee.email),
                    _kv('Tarehe ya Kuzaliwa', formatDate(employee.dateOfBirth)),
                    _kv('Tarehe ya Kuajiriwa', formatDate(employee.dateOfEmployment)),
                    const SizedBox(height: 12),
                    _sectionTitle('Hali ya Mshahara'),
                    if (employee.salaryStatus != null) ...[
                      _kv('Wadhifa', employee.salaryStatus!.occupation),
                      _kv('Kituo', employee.salaryStatus!.workStation),
                      _kv('Mshahara wa Msingi', formatTZS(employee.salaryStatus!.basicSalary)),
                      _kv('Benki', '${employee.salaryStatus!.bankName} (${employee.salaryStatus!.bankAccountNumber})'),
                    ] else
                      const Text('Bado hazijawekwa.', style: TextStyle(color: Colors.black45, fontSize: 11.5)),
                    const SizedBox(height: 12),
                    _sectionTitle('Mchanganuo wa Mshahara (Payroll Snapshot)'),
                    _kv('Ghafi (Gross)', formatTZS(calc.grossSalary)),
                    _kv('NSSF/PSSSF', formatTZS(calc.nssfDeduction)),
                    _kv('TRA PAYE', formatTZS(calc.traPayeTax)),
                    _kv('Makato Mengine', formatTZS(calc.totalOtherDeductions)),
                    _kv('Net Pay', formatTZS(calc.netSalary), emphasize: true),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showSalaryStatusDialog(context, employee);
                    },
                    child: const Text('Hali ya Mshahara'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showArrearsDialog(context, employee);
                    },
                    child: const Text('Makato'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showAllowancesDialog(context, employee);
                    },
                    child: const Text('Posho'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
                    onPressed: () {
                      Navigator.of(context).pop();
                      final nav = Get.find<NavigationController>();
                      nav.goTo('salary_slip');
                    },
                    child: const Text('Nenda Salary Slip'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _brandBlue)),
      );

  Widget _kv(String key, String value, {bool emphasize = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 160, child: Text(key, style: const TextStyle(fontSize: 11.5, color: Colors.black54))),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: emphasize ? FontWeight.w900 : FontWeight.w600,
                      color: emphasize ? _brandBlue : Colors.black87)),
            ),
          ],
        ),
      );
}
