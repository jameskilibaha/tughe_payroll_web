import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/salary_terms_controller.dart';
import '../models/employee.dart';
import '../models/tra_salary_term.dart';
import '../utils/formatters.dart';
import '../utils/payroll_calculator.dart';
import 'widgets/app_status_views.dart';

const _brandBlue = Color(0xFF1E3A8A);
const _slate900 = Color(0xFF0F172A);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onSelectEmployeeForSlip});

  final void Function(Employee) onSelectEmployeeForSlip;

  @override
  Widget build(BuildContext context) {
    final nav = Get.find<NavigationController>();
    final employeeCtrl = Get.find<EmployeeController>();
    final termsCtrl = Get.find<SalaryTermsController>();

    return Obx(() {
      if (employeeCtrl.isLoading.value) {
        return const AppLoadingIndicator(message: 'Inapakua taarifa za dashibodi...');
      }
      final employees = employeeCtrl.employees;
      final traTerms = termsCtrl.traTerms.toList();
      final active = employees.where((e) => e.status == 'Active').toList();
      final blocked = employees.where((e) => e.status == 'Blocked').toList();

      double totalGross = 0, totalAllowances = 0, totalPaye = 0, totalNssf = 0;
      double totalOtherDeductions = 0, totalNet = 0;

      for (final emp in active) {
        final calc = calculateEmployeePayroll(emp, traTerms: traTerms);
        totalGross += calc.grossSalary;
        totalAllowances += calc.totalAllowances;
        totalPaye += calc.traPayeTax;
        totalNssf += calc.nssfDeduction;
        totalOtherDeductions += calc.totalOtherDeductions;
        totalNet += calc.netSalary;
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _banner(nav),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final cards = [
                _statCard(
                  label: 'WAFANYAKAZI WOTE',
                  value: employees.length.toString(),
                  valueColor: _brandBlue,
                  icon: Icons.groups_outlined,
                  iconBg: Colors.blue.shade50,
                  iconColor: _brandBlue,
                  footer: 'Fungiwa: ${blocked.length}',
                  footerAction: ('Orodha', () => nav.goTo('registration')),
                  trailing: '${active.length} Hai',
                ),
                _statCard(
                  label: 'NET PAY (MSHAHARA SAFI)',
                  value: formatTZS(totalNet),
                  valueColor: _slate900,
                  icon: Icons.account_balance_wallet_outlined,
                  iconBg: Colors.green.shade50,
                  iconColor: Colors.green.shade700,
                  footer: 'Ghafi: ${formatTZS(totalGross)}',
                ),
                _statCard(
                  label: 'KODI YA TRA (PAYE)',
                  value: formatTZS(totalPaye),
                  valueColor: Colors.purple.shade900,
                  icon: Icons.calculate_outlined,
                  iconBg: Colors.purple.shade50,
                  iconColor: Colors.purple.shade800,
                  footer: 'NSSF/PSSSF: ${formatTZS(totalNssf)}',
                  footerAction: ('Fomula', () => nav.goTo('settings_salary_terms')),
                ),
                _statCard(
                  label: 'POSHO NA MAKATO',
                  value: formatTZS(totalAllowances),
                  valueColor: Colors.amber.shade800,
                  icon: Icons.card_giftcard,
                  iconBg: Colors.amber.shade50,
                  iconColor: Colors.amber.shade800,
                  footer: 'Arrears: ${formatTZS(totalOtherDeductions)}',
                  footerAction: ('Simamia', () => nav.goTo('allowances')),
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: i == cards.length - 1 ? 0 : 16),
                        child: cards[i],
                      ),
                  ],
                );
              }

              // IntrinsicHeight + stretch keeps every card in the row the same
              // height (the tallest one) without forcing a fixed aspect ratio
              // that can clip content on narrower desktop widths.
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != cards.length - 1) const SizedBox(width: 16),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final table = _employeeTable(employees.take(5).toList(), traTerms, nav);
              final panel = _traPanel(traTerms, nav);
              if (isNarrow) {
                return Column(children: [table, const SizedBox(height: 16), panel]);
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: table),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: panel),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  Widget _banner(NavigationController nav) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: _brandBlue, borderRadius: BorderRadius.circular(16)),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text('CHAMA CHA WAFANYAKAZI WA SERIKALI NA AFYA TANZANIA',
                      style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                const Text('MFUMO WA TUGHE PAYROLL',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text(
                  'Usajili wa watumishi, usimamizi wa mishahara ya msingi, posho, makato ya arrears, na ukokotoaji rasmi wa kodi ya TRA PAYE.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => nav.goTo('registration'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _brandBlue),
                icon: const Icon(Icons.people_outline, size: 16),
                label: const Text('+ Sajili Mpya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              ElevatedButton.icon(
                onPressed: () => nav.goTo('reports'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade500, foregroundColor: Colors.black),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Sehemu ya Ripoti', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
              ),
              ElevatedButton.icon(
                onPressed: () => nav.goTo('salary_slip'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Hati za Mshahara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String footer,
    (String, VoidCallback)? footerAction,
    String? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.black38, letterSpacing: 0.5)),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: valueColor)),
              ),
              if (trailing != null)
                Text(trailing, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(footer,
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
              ),
              if (footerAction != null)
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(10, 20)),
                  onPressed: footerAction.$2,
                  child: Text(footerAction.$1,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brandBlue)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _employeeTable(List<Employee> employees, List<TRASalaryTerm> traTerms, NavigationController nav) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('ORODHA YA WATUMISHI NA MCHANGANUO WA MSHAHARA',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => nav.goTo('registration'),
                child: const Text('Tazama Wote', style: TextStyle(fontSize: 10.5, color: _brandBlue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 60,
              columns: const [
                DataColumn(label: Text('Emp ID & Name', style: TextStyle(fontSize: 10))),
                DataColumn(label: Text('Cheo / Kituo', style: TextStyle(fontSize: 10))),
                DataColumn(label: Text('Basic Pay', style: TextStyle(fontSize: 10)), numeric: true),
                DataColumn(label: Text('Posho', style: TextStyle(fontSize: 10)), numeric: true),
                DataColumn(label: Text('PAYE', style: TextStyle(fontSize: 10)), numeric: true),
                DataColumn(label: Text('Net Pay', style: TextStyle(fontSize: 10)), numeric: true),
                DataColumn(label: Text('Action', style: TextStyle(fontSize: 10))),
              ],
              rows: employees.map<DataRow>((emp) {
                final calc = calculateEmployeePayroll(emp, traTerms: traTerms);
                return DataRow(cells: [
                  DataCell(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emp.id, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brandBlue)),
                      Text(emp.fullName, style: const TextStyle(fontSize: 10.5)),
                    ],
                  )),
                  DataCell(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emp.salaryStatus?.occupation ?? 'Haijawekwa', style: const TextStyle(fontSize: 10.5)),
                      Text(emp.salaryStatus?.workStation ?? '-',
                          style: const TextStyle(fontSize: 9.5, color: Colors.black45)),
                    ],
                  )),
                  DataCell(Text(formatTZS(calc.basicSalary), style: const TextStyle(fontSize: 10.5))),
                  DataCell(Text('+${formatTZS(calc.totalAllowances)}',
                      style: TextStyle(fontSize: 10.5, color: Colors.green.shade700))),
                  DataCell(Text(formatTZS(calc.traPayeTax),
                      style: TextStyle(fontSize: 10.5, color: Colors.purple.shade800))),
                  DataCell(Text(formatTZS(calc.netSalary),
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: _brandBlue))),
                  DataCell(TextButton(
                    onPressed: () {
                      onSelectEmployeeForSlip(emp);
                      nav.goTo('salary_slip');
                    },
                    child: const Text('Slip', style: TextStyle(fontSize: 10, color: _brandBlue, fontWeight: FontWeight.bold)),
                  )),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _traPanel(List<TRASalaryTerm> traTerms, NavigationController nav) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('FOMULA YA KODI YA TRA (PAYE)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => nav.goTo('settings_salary_terms'),
                child: const Text('Badili', style: TextStyle(fontSize: 10.5, color: _brandBlue)),
              ),
            ],
          ),
          const Divider(),
          ...traTerms.map((term) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Term ${term.termNumber}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brandBlue)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                          child: Text('${term.percentage}%',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: _brandBlue)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kiwango: ${formatTZS(term.minSalary)} - ${term.maxSalary >= 999999999 ? "Zaidi" : formatTZS(term.maxSalary)}',
                      style: const TextStyle(fontSize: 10.5),
                    ),
                    if (term.additionAmount > 0)
                      Text('+ Nyongeza ya Kodi: ${formatTZS(term.additionAmount)}',
                          style: TextStyle(fontSize: 9.5, color: Colors.purple.shade700, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NSSF / PSSSF Contribution', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: _brandBlue)),
                SizedBox(height: 2),
                Text('Kutoa 10% ya Mshahara wa Msingi kabla ya kukokotoa kodi ya PAYE.',
                    style: TextStyle(fontSize: 10, color: _brandBlue)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
