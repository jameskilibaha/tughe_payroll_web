import 'package:flutter/material.dart' hide Text;

import '../core/theme.dart';
import '../core/tr_text.dart';
import 'pay_reports_screen.dart';
import 'reports_screen.dart';
import 'statutory_reports_screen.dart';

/// One "Ripoti" menu: the report kinds are tabs inside it - Sehemu ya Ripoti (master sheet, bank, ...),
/// Ripoti za Kisheria (PAYE, NSSF/PSSSF, SDL, WCF) and Ripoti za Makato na Posho.
class ReportsHubScreen extends StatefulWidget {
  const ReportsHubScreen({super.key, this.initialTab = 0, this.onNavigateToSalarySlip});

  final int initialTab;
  final VoidCallback? onNavigateToSalarySlip;

  @override
  State<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends State<ReportsHubScreen> {
  late int _tab = widget.initialTab;

  static const _tabs = <(String, IconData)>[
    ('Sehemu ya Ripoti', Icons.bar_chart),
    ('Ripoti za Kisheria', Icons.gavel_outlined),
    ('Ripoti za Makato na Posho', Icons.receipt_long_outlined),
  ];

  Widget _body() {
    switch (_tab) {
      case 1:
        return const StatutoryReportsScreen();
      case 2:
        return const PayReportsScreen();
      default:
        return ReportsScreen(onNavigateToSalarySlip: widget.onNavigateToSalarySlip);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Pal.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: Pal.border)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < _tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _tab == i ? Pal.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _tab == i ? Pal.primary : Colors.transparent, width: 1.4),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_tabs[i].$2, size: 16, color: _tab == i ? Pal.primary : Pal.textSecondary),
                    const SizedBox(width: 7),
                    Text(_tabs[i].$1,
                        style: TextStyle(fontSize: 12.5, fontWeight: _tab == i ? FontWeight.w800 : FontWeight.w600, color: _tab == i ? Pal.brandText : Pal.textSecondary)),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );

    // On a narrow screen the whole page scrolls (unbounded height): give the report a fixed height there.
    return LayoutBuilder(builder: (context, c) {
      final bounded = c.hasBoundedHeight;
      final body = KeyedSubtree(key: ValueKey(_tab), child: _body());
      return Column(
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          const SizedBox(height: 14),
          if (bounded) Expanded(child: body) else SizedBox(height: 900, child: body),
        ],
      );
    });
  }
}
