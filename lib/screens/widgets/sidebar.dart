import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../controllers/navigation_controller.dart';
import '../../core/i18n.dart';

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
    _NavItem('registration', 'Usajili wa Wafanyakazi', Icons.person_add_alt_1_outlined,
        sublabel: 'Employee Registration'),
    _NavItem('salary_status', 'Hali ya Mshahara', Icons.attach_money,
        sublabel: 'Salary Status'),
    _NavItem('arrears', 'Makato (Arrears)', Icons.trending_down, sublabel: 'Employee Arrears'),
    _NavItem('allowances', 'Nyongeza (Allowances)', Icons.card_giftcard,
        sublabel: 'Employee Allowances'),
    _NavItem('run_payroll', 'Endesha Payroll', Icons.play_circle_outline,
        sublabel: 'Generate / Reverse Payroll'),
    _NavItem('salary_slip', 'Hati ya Mshahara', Icons.description_outlined,
        sublabel: 'Salary Slip / Payslip', badge: 'PDF'),
    _NavItem('reports', 'Sehemu ya Ripoti', Icons.bar_chart,
        sublabel: 'Master Sheet, TRA, NSSF, Bank', badge: 'CSV'),
  ];

  static const _settingsItems = [
    _NavItem('settings_arrears', 'Form ya Arrears', Icons.tune, sublabel: 'Settings za Makato'),
    _NavItem('settings_allowances', 'Form ya Allowances', Icons.card_giftcard,
        sublabel: 'Settings za Posho'),
    _NavItem('settings_salary_terms', 'TRA Formula Settings', Icons.calculate_outlined,
        sublabel: 'Salary Terms'),
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
                        children: _mainItems.map((item) {
                          final badge = item.id == 'registration'
                              ? employeeCount.toString()
                              : item.badge;
                          return _buildTile(item, nav.activeTab.value == item.id, nav, badge, isEn: isEn);
                        }).toList(),
                      )),
                  const SizedBox(height: 20),
                  _sectionLabel(t('MIPANGILIO (SETTINGS)', isEnglish: isEn)),
                  Obx(() => Column(
                        children: _settingsItems
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
                      color: isActive ? Colors.white : Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(badge,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isActive ? _brandBlue : Colors.blue.shade100)),
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
