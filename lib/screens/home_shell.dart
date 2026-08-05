import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/allowances_settings_controller.dart';
import '../controllers/arrears_settings_controller.dart';
import '../controllers/audit_controller.dart';
import '../controllers/employee_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/salary_terms_controller.dart';
import '../controllers/user_management_controller.dart';
import '../utils/boot_loading_toast.dart';
import 'dashboard_screen.dart';
import 'employee_registration_screen.dart';
import 'reports_screen.dart';
import 'run_payroll_screen.dart';
import 'salary_slip_screen.dart';
import 'settings/settings_allowances_screen.dart';
import 'settings/settings_arrears_screen.dart';
import 'settings/settings_salary_terms_screen.dart';
import 'settings/settings_user_controller_screen.dart';
import 'widgets/header.dart';
import 'widgets/sidebar.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    // Scheduled for after the first frame - by then GetMaterialApp's
    // Navigator/Overlay exists, so it's safe to show a Get snackbar. Each
    // controller already started fetching from the backend as soon as it
    // was created (see their onInit); this just shows a "loading" toast
    // for however much of that work is still in flight.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showBootLoadingToast(readyFutures: [
        Get.find<EmployeeController>().ready,
        Get.find<ArrearsSettingsController>().ready,
        Get.find<AllowancesSettingsController>().ready,
        Get.find<SalaryTermsController>().ready,
        Get.find<UserManagementController>().ready,
        Get.find<AuditController>().ready,
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final nav = Get.find<NavigationController>();
    final employeeCtrl = Get.find<EmployeeController>();

    return Scaffold(
      appBar: const AppHeader(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;
          return Obx(() {
            final sidebar = Sidebar(employeeCount: employeeCtrl.employees.length);
            final content = Padding(
              padding: EdgeInsets.only(top: isNarrow ? 16 : 0, left: isNarrow ? 0 : 20),
              child: _buildContent(nav.activeTab.value, nav),
            );

            if (isNarrow) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [sidebar, content],
                ),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sidebar,
                Expanded(child: content),
              ],
            );
          });
        }),
      ),
    );
  }

  Widget _buildContent(String tab, NavigationController nav) {
    switch (tab) {
      case 'dashboard':
        return DashboardScreen(onSelectEmployeeForSlip: nav.goToPayslip);
      case 'registration':
      case 'salary_status':
      case 'arrears':
      case 'allowances':
        return EmployeeRegistrationScreen(onGeneratePayslip: nav.goToPayslip);
      case 'settings_arrears':
        return const SettingsArrearsScreen();
      case 'run_payroll':
        return const RunPayrollScreen();
      case 'settings_allowances':
        return const SettingsAllowancesScreen();
      case 'settings_salary_terms':
        return const SettingsSalaryTermsScreen();
      case 'settings_user_controller':
        return const SettingsUserControllerScreen();
      case 'reports':
        return ReportsScreen(onNavigateToSalarySlip: () => nav.goTo('salary_slip'));
      case 'salary_slip':
        return Obx(() => SalarySlipScreen(
              key: ValueKey(nav.selectedEmployeeForSlip.value?.id),
              initialEmployee: nav.selectedEmployeeForSlip.value,
            ));
      default:
        return DashboardScreen(onSelectEmployeeForSlip: nav.goToPayslip);
    }
  }
}
