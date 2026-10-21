import 'package:get/get.dart';

import '../models/employee.dart';

/// Mirrors the `activeTab` / `searchQuery` state in App.tsx.
/// Tabs: dashboard, registration, salary_status, arrears, allowances,
/// settings_arrears, settings_allowances, settings_salary_terms,
/// settings_user_controller, salary_slip.
class NavigationController extends GetxController {
  final RxString activeTab = 'dashboard'.obs;
  final RxString searchQuery = ''.obs;
  final Rxn<Employee> selectedEmployeeForSlip = Rxn<Employee>();

  /// The old separate pages "Hali ya Mshahara", "Makato" and "Nyongeza" are now part of the one employees page.
  static const _merged = {'salary_status', 'arrears', 'allowances'};

  void goTo(String tab) => activeTab.value = _merged.contains(tab) ? 'registration' : tab;

  void goToPayslip(Employee employee) {
    selectedEmployeeForSlip.value = employee;
    activeTab.value = 'salary_slip';
  }
}
