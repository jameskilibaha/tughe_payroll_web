import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/employee_controller.dart';
import 'controllers/arrears_settings_controller.dart';
import 'controllers/allowances_settings_controller.dart';
import 'controllers/salary_terms_controller.dart';
import 'controllers/user_management_controller.dart';
import 'controllers/audit_controller.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/payroll_controller.dart';
import 'core/theme.dart';
import 'core/i18n.dart';
import 'network/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

void main() {
  // Single shared API client so every controller talks to the same backend
  // session (JWT token storage is shared regardless, but this keeps the
  // wiring explicit and makes the app easy to point at a different backend
  // - see lib/network/app_config.dart - or to fake in tests).
  final apiService = ApiService();
  Get.put<ApiService>(apiService, permanent: true);

  // GetX controllers: domain/business state (mirrors the various
  // `useState` + `useEffect(localStorage)` blocks in App.tsx), now backed
  // by the real FastAPI backend via [apiService] with a local-cache
  // fallback for offline use.
  Get.put(AuthController(apiService: apiService), permanent: true);
  Get.put(EmployeeController(apiService: apiService), permanent: true);
  Get.put(ArrearsSettingsController(apiService: apiService), permanent: true);
  Get.put(AllowancesSettingsController(apiService: apiService), permanent: true);
  Get.put(SalaryTermsController(apiService: apiService), permanent: true);
  Get.put(UserManagementController(apiService: apiService), permanent: true);
  Get.put(AuditController(apiService: apiService), permanent: true);
  Get.put(PayrollController(apiService: apiService), permanent: true);
  Get.put(NavigationController(), permanent: true);

  runApp(const TughePayrollApp());
}

class TughePayrollApp extends StatelessWidget {
  const TughePayrollApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return GetMaterialApp(
            title: 'Mfumo wa Mishahara TUGHE',
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: themeProvider.mode,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

/// Shows the login screen or the main app shell depending on auth state.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() {
      if (auth.isLoading.value) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return auth.isLoggedIn ? const HomeShell() : const LoginScreen();
    });
  }
}
