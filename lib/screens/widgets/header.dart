import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/employee_controller.dart';
import '../../controllers/navigation_controller.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../network/api_service.dart';
import 'editable_avatar.dart';
import 'tughe_logo.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';

const _brandBlue = Color(0xFF1E3A8A);

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final nav = Get.find<NavigationController>();
    final employees = Get.find<EmployeeController>();
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final isEn = localeProvider.isEnglish;

    return Material(
      color: _brandBlue,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;
            return Row(
              children: [
                InkWell(
                  onTap: () => nav.goTo('dashboard'),
                  child: Row(
                    children: [
                      const TugheLogo(size: 40, radius: 8),
                      const SizedBox(width: 12),
                      if (!isNarrow)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(t('MFUMO WA TUGHE PAYROLL', isEnglish: isEn),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(width: 8),
                                _pill('v2.5', Colors.blue.shade700, Colors.blue.shade100),
                                const SizedBox(width: 4),
                                _pill('● Backend Connected', Colors.green.shade700, Colors.green.shade100),
                              ],
                            ),
                            Text('Tanzania Union of Government and Health Employees',
                                style: TextStyle(color: Colors.blue.shade100.withOpacity(0.85), fontSize: 10.5)),
                          ],
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                if (!isNarrow)
                  SizedBox(
                    width: 220,
                    child: TextField(
                      onChanged: (v) => nav.searchQuery.value = v,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: t('Tafuta Mfanyakazi / ID...', isEnglish: isEn),
                        hintStyle: TextStyle(color: Colors.blue.shade100.withOpacity(0.7), fontSize: 12),
                        prefixIcon: Icon(Icons.search, size: 16, color: Colors.blue.shade200),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.25),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue.shade700.withOpacity(0.6)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                if (!isNarrow)
                  Obx(() => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text('${t('Hai', isEnglish: isEn)}: ${employees.activeCount}',
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Text('${t('Fungiwa', isEnglish: isEn)}: ${employees.blockedCount}',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Text('${t('Jumla', isEnglish: isEn)}: ${employees.employees.length}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                const SizedBox(width: 12),
                Obx(() => ElevatedButton.icon(
                      onPressed: () => nav.goTo('salary_slip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: nav.activeTab.value == 'salary_slip' ? Colors.white : Colors.blue.shade800,
                        foregroundColor: nav.activeTab.value == 'salary_slip' ? _brandBlue : Colors.white,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.description_outlined, size: 15),
                      label: const Text('Salary Slip', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    )),
                const SizedBox(width: 12),
                Obx(() {
                  final user = auth.currentUser.value;
                  if (user == null) return const SizedBox.shrink();
                  return Row(
                    children: [
                      if (!isNarrow)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(user.role,
                                style: TextStyle(color: Colors.blue.shade100.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold)),
                            Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      const SizedBox(width: 10),
                      EditableAvatar(
                        photoFileName: user.photoFileName,
                        fetchBytes: (name) => Get.find<ApiService>().fetchUserPhotoBytes(name),
                        fallbackText: user.avatarInitials,
                        radius: 16,
                        backgroundColor: Colors.blue.shade700,
                        onPhotoPicked: (photo) => auth.updateOwnPhoto(photo),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        tooltip: isEn ? 'Language: English (tap for Kiswahili)' : 'Lugha: Kiswahili (bonyeza kwa English)',
                        onPressed: () => localeProvider.toggle(),
                        icon: Text(isEn ? 'EN' : 'SW',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        tooltip: themeProvider.isDark ? 'Light Mode' : 'Dark Mode',
                        onPressed: () => themeProvider.toggle(),
                        icon: Icon(themeProvider.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                            size: 18, color: Colors.white70),
                      ),
                      IconButton(
                        tooltip: tr('Toka kwenye Mfumo (Sign Out)'),
                        onPressed: () => auth.logout(),
                        icon: const Icon(Icons.logout, size: 18, color: Colors.white70),
                      ),
                    ],
                  );
                }),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.bold)),
      );
}
