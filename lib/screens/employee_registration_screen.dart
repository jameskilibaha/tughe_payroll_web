import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';

import '../controllers/employee_controller.dart';
import '../controllers/navigation_controller.dart';
import '../models/employee.dart';
import '../network/api_service.dart';
import 'widgets/employee_form_dialog.dart';
import 'widgets/import_employees_dialog.dart';
import 'widgets/employee_salary_status_dialog.dart';
import 'widgets/employee_setup_dialog.dart';
import 'widgets/employee_arrears_dialog.dart';
import 'widgets/employee_allowances_dialog.dart';
import 'widgets/employee_detail_dialog.dart';
import 'widgets/editable_avatar.dart';
import 'widgets/responsive_header_bar.dart';
import 'widgets/app_status_views.dart';
import 'widgets/pagination_bar.dart';
import '../core/tr_text.dart';
import '../core/translations.dart';
import 'widgets/full_width_scroll.dart';
import '../core/theme.dart';

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
  int _page = 0;
  int _pageSize = 25;

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
              color: Pal.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Pal.border),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveHeaderBar(
                  title: Text('WAFANYAKAZI: USAJILI, MSHAHARA, MAKATO NA POSHO',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Pal.brandText)),
                  actions: [
                    OutlinedButton.icon(
                      onPressed: () => showDialog<bool>(context: context, builder: (_) => const ImportEmployeesDialog()),
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Ingiza kutoka Excel/CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _openForm(context, employeeCtrl, null),
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
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search, size: 16),
                          hintText: tr('Tafuta Jina au ID...'),
                        ),
                        onChanged: (v) => setState(() {
                          _searchFilter = v;
                          _page = 0;
                        }),
                      ),
                    ),
                    _dropdown('Jinsia (Gender)', _filterGender, const ['All', 'Male', 'Female'],
                        (v) => setState(() {
                          _filterGender = v!;
                          _page = 0;
                        })),
                    _dropdown('Hali (Status)', _filterStatus, const ['All', 'Active', 'Blocked'],
                        (v) => setState(() {
                          _filterStatus = v!;
                          _page = 0;
                        })),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Pal.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Pal.border),
              ),
              child: employeeCtrl.isLoading.value
                  ? const AppLoadingIndicator(message: 'Inapakua wafanyakazi kutoka kwenye seva...')
                  : (employeeCtrl.errorMessage.value.isNotEmpty && employeeCtrl.employees.isEmpty)
                      ? AppErrorRetryView(
                          message: employeeCtrl.errorMessage.value,
                          onRetry: employeeCtrl.refreshFromBackend,
                        )
                      : list.isEmpty
                          ? Center(
                              child: Text('Hakuna Wafanyakazi Waliopatikana', style: TextStyle(color: Pal.textMuted)))
                          : Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: FullWidthScroll(
 child: DataTable(
                                        columns: const [
                                          DataColumn(label: Text('ID / Jina')),
                                          DataColumn(label: Text('Simu / Barua Pepe')),
                                          DataColumn(label: Text('Cheo')),
                                          DataColumn(label: Text('Hali')),
                                          DataColumn(label: Text('Vitendo (Actions)')),
                                        ],
                                        // Only ONE page of rows is built: hundreds of rows (each with a
                                        // photo request) used to freeze the screen.
                                        rows: pageSlice(list, _page, _pageSize)
                                            .map((emp) => _buildRow(context, emp, employeeCtrl))
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                PaginationBar(
                                  total: list.length,
                                  page: _page,
                                  pageSize: _pageSize,
                                  onPageChanged: (p) => setState(() => _page = p),
                                  onPageSizeChanged: (n) => setState(() {
                                    _pageSize = n;
                                    _page = 0;
                                  }),
                                ),
                              ],
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
        decoration: InputDecoration(isDense: true, labelText: tr(label), labelStyle: const TextStyle(fontSize: 10)),
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
              Text(emp.id, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Pal.brandText)),
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
          Text(emp.email, style: TextStyle(fontSize: 9.5, color: Pal.textMuted)),
        ],
      )),
      DataCell(Text(emp.salaryStatus?.occupation ?? 'Haijawekwa', style: const TextStyle(fontSize: 10.5))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isBlocked ? Pal.tint(Colors.red) : Pal.tint(Colors.green),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(isBlocked ? 'Blocked' : 'Active',
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: isBlocked ? Pal.fg(Colors.red.shade700) : Pal.fg(Colors.green.shade700))),
      )),
      DataCell(Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: tr('Angalia Taarifa (View)'),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            onPressed: () => showEmployeeDetailDialog(context, emp),
          ),
          IconButton(
            tooltip: tr(isBlocked ? 'Amefungiwa - fungua kwanza (Blocked - unblock first)' : 'Hariri (Edit)'),
            icon: Icon(Icons.edit_outlined, size: 16, color: isBlocked ? Pal.textMuted : null),
            onPressed: isBlocked ? null : () => _openForm(context, ctrl, emp),
          ),
          IconButton(
            tooltip: tr(isBlocked ? 'Amefungiwa - fungua kwanza (Blocked - unblock first)' : 'Usajili Kamili: mshahara, makato na posho'),
            icon: Icon(Icons.checklist, size: 17, color: isBlocked ? Pal.textMuted : (emp.salaryStatus == null ? Pal.fg(Colors.orange.shade800) : Pal.primary)),
            onPressed: isBlocked ? null : () => showEmployeeSetupDialog(context, emp),
          ),
          IconButton(
            tooltip: tr(isBlocked ? 'Amefungiwa - fungua kwanza (Blocked - unblock first)' : 'Hali ya Mshahara (Salary Status)'),
            icon: Icon(Icons.attach_money, size: 16, color: isBlocked ? Pal.textMuted : null),
            onPressed: isBlocked ? null : () => showSalaryStatusDialog(context, emp),
          ),
          IconButton(
            tooltip: tr(isBlocked ? 'Amefungiwa - fungua kwanza (Blocked - unblock first)' : 'Makato (Arrears)'),
            icon: Icon(Icons.trending_down, size: 16, color: isBlocked ? Pal.textMuted : null),
            onPressed: isBlocked ? null : () => showArrearsDialog(context, emp),
          ),
          IconButton(
            tooltip: tr(isBlocked ? 'Amefungiwa - fungua kwanza (Blocked - unblock first)' : 'Posho (Allowances)'),
            icon: Icon(Icons.card_giftcard, size: 16, color: isBlocked ? Pal.textMuted : null),
            onPressed: isBlocked ? null : () => showAllowancesDialog(context, emp),
          ),
          IconButton(
            tooltip: tr('Salary Slip'),
            icon: const Icon(Icons.description_outlined, size: 16),
            onPressed: () => widget.onGeneratePayslip(emp),
          ),
          IconButton(
            tooltip: tr(isBlocked ? 'Fungua (Unblock)' : 'Fungia (Block)'),
            icon: _togglingBlockIds.contains(emp.id)
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(isBlocked ? Icons.lock_open : Icons.lock_outline,
                    size: 16, color: isBlocked ? Pal.fg(Colors.green.shade700) : Pal.fg(Colors.red.shade700)),
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

  Future<void> _openForm(BuildContext context, EmployeeController ctrl, Employee? existing) async {
    final createdId = await showDialog<String>(
      context: context,
      builder: (_) => EmployeeFormDialog(existing: existing),
    );
    // A NEW employee was registered: go straight on to his salary status, deductions and allowances.
    if (existing == null && createdId != null && createdId.isNotEmpty && context.mounted) {
      final created = ctrl.employees.firstWhereOrNull((e) => e.id == createdId);
      if (created != null) await showEmployeeSetupDialog(context, created);
    }
  }
}
