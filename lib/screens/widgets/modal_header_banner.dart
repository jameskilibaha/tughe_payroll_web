import 'package:flutter/material.dart';

/// Branded gradient header banner used at the top of employee action dialogs
/// (Salary Status, Arrears, Allowances, Detail) — mirrors the colored
/// `bg-gradient-to-r ...` header bars from the original React modals
/// (icon in a translucent box, bold title, subtitle, and a close button).
class ModalHeaderBanner extends StatelessWidget {
  const ModalHeaderBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.iconColor,
    required this.subtitleColor,
    this.onClose,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color iconColor;
  final Color subtitleColor;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 11)),
              ],
            ),
          ),
          if (onClose != null)
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 20, color: subtitleColor),
              ),
            ),
        ],
      ),
    );
  }
}
