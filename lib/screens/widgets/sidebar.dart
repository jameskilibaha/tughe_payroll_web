import 'package:flutter/material.dart' hide Text;
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../models/permission_row.dart';
import '../../core/theme.dart';
import '../../controllers/navigation_controller.dart';
import '../../core/i18n.dart';
import '../../core/tr_text.dart';
import 'tughe_logo.dart';

const _brandBlue = Color(0xFF1E3A8A);

class _NavItem {
  final String id;
  final String label;
  final String? sublabel;
  final IconData icon;
  final String? badge;

  const _NavItem(this.id, this.label, this.icon, {this.sublabel, this.badge});
}

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.employeeCount});

  final int employeeCount;

  static const _mainItems = [
    _NavItem('dashboard', 'Muhtasari (Dashboard)', Icons.dashboard_outlined),
    _NavItem('chat', 'Mazungumzo (Chat)', Icons.forum_outlined, sublabel: 'Live Chat'),
    _NavItem('registration', 'Wafanyakazi', Icons.groups_outlined,
        sublabel: 'Usajili, Mshahara, Makato, Posho'),
    _NavItem('adjustments', 'Marekebisho ya Mwezi', Icons.tune, sublabel: 'Overtime, Bonasi, Makato ya Mara Moja'),
    _NavItem('run_payroll', 'Endesha Payroll', Icons.play_circle_outline,
        sublabel: 'Generate / Reverse Payroll'),
    _NavItem('salary_slip', 'Hati ya Mshahara', Icons.description_outlined,
        sublabel: 'Salary Slip / Payslip', badge: 'PDF'),
    _NavItem('reports', 'Ripoti', Icons.bar_chart,
        sublabel: 'Master Sheet, Kisheria, Makato na Posho', badge: 'PDF'),
    _NavItem('variance', 'Tofauti ya Mwezi', Icons.compare_arrows, sublabel: 'Mwezi huu dhidi ya uliopita'),
  ];

  static const _hrItems = [
    _NavItem('hr_leave', 'Likizo (Leave)', Icons.beach_access_outlined, sublabel: 'Maombi, Idhini, Salio'),
    _NavItem('hr_records', 'Rekodi za Wafanyakazi', Icons.badge_outlined, sublabel: 'Mawasiliano, Wategemezi, Elimu, Mikataba'),
  ];

  /// What each role may see in the menu (the server still checks every call). An Admin, and an old
  /// server that reports no role, see everything; Payroll does not see HR; HR does not see anything about pay.
  static const _payOnlyIds = {
    'dashboard', 'adjustments', 'run_payroll', 'salary_slip', 'reports', 'variance',
    'settings_arrears', 'settings_allowances', 'settings_salary_terms', 'settings_statutory',
  };
  static bool visibleFor(String id, String role) {
    if (!kAllRoles.contains(role) || role == kRoleAdmin) return true;
    if (role == kRoleHr) return !_payOnlyIds.contains(id);
    if (role == kRoleAccountant) return !id.startsWith('hr_');
    return true;
  }

  static const _settingsItems = [
    _NavItem('settings_arrears', 'Form ya Arrears', Icons.tune, sublabel: 'Settings za Makato'),
    _NavItem('settings_allowances', 'Form ya Allowances', Icons.card_giftcard,
        sublabel: 'Settings za Posho'),
    _NavItem('settings_salary_terms', 'TRA Formula Settings', Icons.calculate_outlined,
        sublabel: 'Salary Terms'),
    _NavItem('settings_statutory', 'Mipangilio ya Kisheria', Icons.policy_outlined, sublabel: 'NSSF, PSSSF, SDL, WCF, HESLB'),
    _NavItem('settings_user_controller', 'User Controller & Audit', Icons.verified_user_outlined,
        sublabel: 'Password, Block, Audit Log'),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = Get.find<NavigationController>();
    final isEn = context.watch<LocaleProvider>().isEnglish;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _brandBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1B4B).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionLabel(t('MODULI KUU', isEnglish: isEn)),
                  Obx(() => Column(
                        children: _mainItems.where((item) => visibleFor(item.id, Get.find<AuthController>().currentUser.value?.role ?? '')).map((item) {
                          final unreadChat = Get.find<ChatController>().totalUnread.value;
                          final badge = item.id == 'registration'
                              ? employeeCount.toString()
                              : item.id == 'chat'
                                  ? (unreadChat > 0 ? (unreadChat > 99 ? '99+' : '$unreadChat') : null)
                                  : item.badge;
                          return _buildTile(item, nav.activeTab.value == item.id, nav, badge, isEn: isEn);
                        }).toList(),
                      )),
                  Obx(() {
                    final role = Get.find<AuthController>().currentUser.value?.role ?? '';
                    final items = _hrItems.where((item) => visibleFor(item.id, role)).toList();
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SizedBox(height: 20),
                      _sectionLabel(t('RASILIMALI WATU (HR)', isEnglish: isEn)),
                      ...items.map((item) => _buildTile(item, nav.activeTab.value == item.id, nav, null, isEn: isEn)),
                    ]);
                  }),
                  const SizedBox(height: 20),
                  _sectionLabel(t('MIPANGILIO (SETTINGS)', isEnglish: isEn)),
                  Obx(() => Column(
                        children: _settingsItems
                            .where((item) => visibleFor(item.id, Get.find<AuthController>().currentUser.value?.role ?? ''))
                            .map((item) => item.id == 'settings_user_controller' && !Get.find<AuthController>().isAdmin
                                ? const _NavItem('settings_user_controller', 'Nenosiri Langu', Icons.lock_outline,
                                    sublabel: 'My Password')
                                : item)
                            .map((item) => _buildTile(item, nav.activeTab.value == item.id, nav, null,
                                isSettings: true, isEn: isEn))
                            .toList(),
                      )),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(padding: EdgeInsets.only(bottom: 8), child: TugheLogo(size: 44, radius: 10)),
                Text(t('CHAMA CHA TUGHE', isEnglish: isEn),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                const SizedBox(height: 2),
                Text(t('Mfumo wa Mshahara & Posho', isEnglish: isEn),
                    style: TextStyle(color: Colors.blue.shade100, fontSize: 10)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(t('MFUMO UPO HAI', isEnglish: isEn),
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(text,
            style: TextStyle(color: Colors.blue.shade100.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      );

  Widget _buildTile(_NavItem item, bool isActive, NavigationController nav, String? badge,
      {bool isSettings = false, required bool isEn}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => nav.goTo(item.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: isActive
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(
                          color: isSettings ? Colors.amber.shade300 : Colors.white, width: 3),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  )
                : null,
            child: Row(
              children: [
                Icon(item.icon,
                    size: 16,
                    color: isActive
                        ? (isSettings ? Colors.amber.shade300 : Colors.white)
                        : Colors.blue.shade200),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t(item.label, isEnglish: isEn),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600)),
                      if (item.sublabel != null)
                        Text(t(item.sublabel!, isEnglish: isEn),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.blue.shade100.withOpacity(0.8), fontSize: 9.5)),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.id == 'chat' ? AppColors.gold : (isActive ? Colors.white : Colors.black26),
                      borderRadius: BorderRadius.circular(item.id == 'chat' ? 8 : 4),
                    ),
                    child: Text(badge,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: item.id == 'chat' ? AppColors.slate900 : (isActive ? _brandBlue : Colors.blue.shade100))),
                  )
                else if (isSettings)
                  Icon(Icons.chevron_right,
                      size: 14, color: isActive ? Colors.amber.shade300 : Colors.blue.shade200),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
