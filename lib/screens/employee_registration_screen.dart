import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_controller.dart';
import '../controllers/navigation_controller.dart';
import '../models/employee.dart';
import '../network/api_service.dart';
import 'widgets/employee_form_dialog.dart';
import 'widgets/employee_salary_status_dialog.dart';
import 'widgets/employee_arrears_dialog.dart';
import 'widgets/employee_allowances_dialog.dart';
import 'widgets/employee_detail_dialog.dart';
import 'widgets/editable_avatar.dart';
import 'widgets/responsive_header_bar.dart';
import 'widgets/app_status_views.dart';

const _brandBlue = Color(0xFF1E3A8A);

class EmployeeRegistrationScreen extends StatefulWidget {
  const EmployeeRegistrationScreen({super.key, required this.onGeneratePayslip});

  final void Function(Employee) onGeneratePayslip;

  @override
  State<EmployeeRegistrationScreen> createState() => _EmployeeRegistrationScreenState();
}

class _EmployeeRegistrationScreenState extends State<EmployeeRegistrationScreen> {
  String _filterGender = 'All';
  String _filterStatus = 'All';
  String _searchFilter = '';
  final Set<String> _togglingBlockIds = {};

  @override
  Widget build(BuildContext context) {
    final employeeCtrl = Get.find<EmployeeController>();
    final nav = Get.find<NavigationController>();

    return Obx(() {
      var list = employeeCtrl.employees.toList();

      final query = (nav.searchQuery.value.isNotEmpty ? nav.searchQuery.value : _searchFilter).toLowerCase();
      if (query.isNotEmpty) {
        list = list
            .where((e) =>
                e.fullName.toLowerCase().contains(query) ||
                e.id.toLowerCase().contains(query) ||
                e.email.toLowerCase().contains(query))
            .toList();
      }
      if (_filterGender != 'All') {
        list = list.where((e) => e.gender == _filterGender).toList();
      }
      if (_filterStatus != 'All') {
        list = list.where((e) => e.status == _filterStatus).toList();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveHeaderBar(
                  title: const Text('USAJILI WA WAFANYAKAZI (EMPLOYEE REGISTRATION)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _brandBlue)),
                  actions: [
                    ElevatedButton.icon(
                      onPressed: () => _openForm(context, employeeCtrl, null),
                      style: ElevatedButton.styleFrom(backgroundColor: _brandBlue, foregroundColor: Colors.white),
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('Sajili Mfanyakazi Mpya', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 240,
                      child: TextField(
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search, size: 16),
                          hintText: 'Tafuta Jina au ID...',
                        ),
                        onChanged: (v) => setState(() => _searchFilter = v),
                      ),
                    ),
                    _dropdown('Jinsia (Gender)', _filterGender, const ['All', 'Male', 'Female'],
                        (v) => setState(() => _filterGender = v!)),
                    _dropdown('Hali (Status)', _filterStatus, const ['All', 'Active', 'Blocked'],
                        (v) => setState(() => _filterStatus = v!)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: employeeCtrl.isLoading.value
                  ? const AppLoadingIndicator(message: 'Inapakua wafanyakazi kutoka kwenye seva...')
                  : (employeeCtrl.errorMessage.value.isNotEmpty && employeeCtrl.employees.isEmpty)
                      ? AppErrorRetryView(
                          message: employeeCtrl.errorMessage.value,
                          onRetry: employeeCtrl.refreshFromBackend,
                        )
                      : list.isEmpty
                          ? const Center(
                              child: Text('Hakuna Wafanyakazi Waliopatikana', style: TextStyle(color: Colors.black45)))
                          : SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('ID / Jina')),
                                    DataColumn(label: Text('Simu / Barua Pepe')),
                                    DataColumn(label: Text('Cheo')),
                                    DataColumn(label: Text('Hali')),
                                    DataColumn(label: Text('Vitendo (Actions)')),
                                  ],
                                  rows: list.map((emp) => _buildRow(context, emp, employeeCtrl)).toList(),
                                ),
                              ),
                            ),
            ),
          ),
        ],
      );
    });
  }

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(isDense: true, labelText: label, labelStyle: const TextStyle(fontSize: 10)),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 11)))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  DataRow _buildRow(BuildContext context, Employee emp, EmployeeController ctrl) {
    final isBlocked = emp.status == 'Blocked';
    return DataRow(cells: [
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EditableAvatar(
            photoFileName: emp.photoFileName,
            fetchBytes: (name) => Get.find<ApiService>().fetchEmployeePhotoBytes(name),
            fallbackText: emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : '?',
            radius: 16,
            backgroundColor: _brandBlue,
            onPhotoPicked: (photo) => ctrl.updatePhoto(emp.id, photo),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emp.id, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brandBlue)),
              Text(emp.fullName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      )),
      DataCell(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emp.mobileNumber, style: const TextStyle(fontSize: 10.5)),
          Text(emp.email, style: const TextStyle(fontSize: 9.5, color: Colors.black45)),
        ],
      )),
      DataCell(Text(emp.salaryStatus?.occupation ?? 'Haijawekwa', style: const TextStyle(fontSize: 10.5))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isBlocked ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(isBlocked ? 'Blocked' : 'Active',
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: isBlocked ? Colors.red.shade700 : Colors.green.shade700)),
      )),
      DataCell(Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: 'Angalia Taarifa (View)',
            icon: const Icon(Icons.visibility_outlined, size: 16),
            onPressed: () => showEmployeeDetailDialog(context, emp),
          ),
          IconButton(
            tooltip: isBlocked ? 'Amefungiwa - fungua kwanza (Blocked - unblock first)' : 'Hariri (Edit)',
            icon: Icon(Icons.edit_outlined, size: 16, color: isBlocked ? Colors.black26 : null),
            onPressed: isBlocked ? null : () => _openForm(context, ctrl, emp),
          ),
          IconButton(
            tooltip: isBlocked ? 'Amefungiwa - fungua kwanza (Blocked - unblock first)' : 'Hali ya Mshahara (Salary Status)',
            icon: Icon(Icons.attach_money, size: 16, color: isBlocked ? Colors.black26 : null),
            onPressed: isBlocked ? null : () => showSalaryStatusDialog(context, emp),
          ),
          IconButton(
            tooltip: isBlocked ? 'Amefungiwa - fungua kwanza (Blocked - unblock first)' : 'Makato (Arrears)',
            icon: Icon(Icons.trending_down, size: 16, color: isBlocked ? Colors.black26 : null),
            onPressed: isBlocked ? null : () => showArrearsDialog(context, emp),
          ),
          IconButton(
            tooltip: isBlocked ? 'Amefungiwa - fungua kwanza (Blocked - unblock first)' : 'Posho (Allowances)',
            icon: Icon(Icons.card_giftcard, size: 16, color: isBlocked ? Colors.black26 : null),
            onPressed: isBlocked ? null : () => showAllowancesDialog(context, emp),
          ),
          IconButton(
            tooltip: 'Salary Slip',
            icon: const Icon(Icons.description_outlined, size: 16),
            onPressed: () => widget.onGeneratePayslip(emp),
          ),
          IconButton(
            tooltip: isBlocked ? 'Fungua (Unblock)' : 'Fungia (Block)',
            icon: _togglingBlockIds.contains(emp.id)
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(isBlocked ? Icons.lock_open : Icons.lock_outline,
                    size: 16, color: isBlocked ? Colors.green.shade700 : Colors.red.shade700),
            onPressed: _togglingBlockIds.contains(emp.id)
                ? null
                : () async {
                    setState(() => _togglingBlockIds.add(emp.id));
                    await ctrl.toggleBlockStatus(emp.id);
                    if (mounted) setState(() => _togglingBlockIds.remove(emp.id));
                  },
          ),
        ],
      )),
    ]);
  }

  void _openForm(BuildContext context, EmployeeController ctrl, Employee? existing) {
    showDialog(
      context: context,
      builder: (_) => EmployeeFormDialog(existing: existing),
    );
  }
}
