import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import '../../utils/formatters.dart';
import '../../core/tr_text.dart';
import '../../core/translations.dart';
import '../../core/theme.dart';

class ChartSlice {
  const ChartSlice(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// Card with a title used by every dashboard chart.
class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Pal.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Pal.text)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(fontSize: 10, color: Pal.textMuted)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class EmptyChart extends StatelessWidget {
  const EmptyChart({super.key, this.message = 'Hakuna taarifa za kuonyesha bado.'});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(child: Text(message, style: TextStyle(fontSize: 11, color: Pal.textMuted))),
      );
}

/// Donut / pie chart with a legend (label, value, percent) beside it.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.centerTop,
    this.centerBottom,
    this.valueFormat,
    this.size = 140,
  });

  final List<ChartSlice> slices;
  final String? centerTop;
  final String? centerBottom;
  final String Function(double)? valueFormat;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, e) => s + (e.value > 0 ? e.value : 0));
    if (total <= 0) return const EmptyChart();
    final fmt = valueFormat ?? formatAmount;

    final donut = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size(size, size), painter: _DonutPainter(slices, total)),
          if (centerTop != null || centerBottom != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (centerTop != null)
                  // Exact amount, shrunk to fit the ring - never abbreviated (1.2M) or rounded.
                  SizedBox(
                    width: size * 0.62,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(centerTop!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Pal.text)),
                    ),
                  ),
                if (centerBottom != null)
                  Text(centerBottom!, style: TextStyle(fontSize: 9, color: Pal.textMuted)),
              ],
            ),
        ],
      ),
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('${s.label}', style: const TextStyle(fontSize: 10.5), overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text('${fmt(s.value)} (${(s.value / total * 100).toStringAsFixed(3)}%)',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 12,
      children: [donut, legend],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.total);

  final List<ChartSlice> slices;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.20;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    var start = -math.pi / 2;
    const gap = 0.02;
    for (final s in slices) {
      if (s.value <= 0) continue;
      final sweep = s.value / total * 2 * math.pi;
      paint.color = s.color;
      canvas.drawArc(rect, start, math.max(sweep - gap, 0.001), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices || old.total != total;
}

class ColumnItem {
  const ColumnItem(this.label, this.value, {this.tooltip});
  final String label;
  final double value;
  final String? tooltip;
}

/// Vertical bars with the value above and the label below (hover for details).
class ColumnChart extends StatelessWidget {
  const ColumnChart({super.key, required this.items, this.color, this.valueFormat, this.height = 190});

  final List<ColumnItem> items;
  /// Bar colour; null = the theme's chart blue.
  final Color? color;
  final String Function(double)? valueFormat;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = items.fold<double>(0, (m, e) => math.max(m, e.value));
    if (items.isEmpty || maxV <= 0) return const EmptyChart();
    final fmt = valueFormat ?? formatAmount;
    const labelArea = 42.0; // value text above + label below
    final barArea = height - labelArea - 14;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final it in items)
            Expanded(
              child: Tooltip(
                message: it.tooltip ?? '${it.label}: ${fmt(it.value)}',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Exact value, shrunk to the column width when it is long.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(fmt(it.value), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      height: math.max(it.value / maxV * barArea, it.value > 0 ? 3 : 0),
                      decoration: BoxDecoration(
                        color: color ?? Pal.chartBlue,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                      ),
                    ),
                    Container(height: 1, color: Pal.border),
                    const SizedBox(height: 4),
                    Text(it.label, style: TextStyle(fontSize: 9.5, color: Pal.textSecondary), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal bars - best for ranked categories with long names.
class BarList extends StatelessWidget {
  const BarList({super.key, required this.items, this.color, this.valueFormat});

  final List<ChartSlice> items;
  /// Fallback bar colour for items without their own; null = the theme's chart blue.
  final Color? color;
  final String Function(double)? valueFormat;

  @override
  Widget build(BuildContext context) {
    final maxV = items.fold<double>(0, (m, e) => math.max(m, e.value));
    if (items.isEmpty || maxV <= 0) return const EmptyChart();
    final fmt = valueFormat ?? formatAmount;
    return Column(
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Tooltip(
              message: '${it.label}: ${fmt(it.value)}',
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(it.label, style: const TextStyle(fontSize: 10.5), overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(height: 12, decoration: BoxDecoration(color: Pal.surfaceAlt, borderRadius: BorderRadius.circular(6))),
                        FractionallySizedBox(
                          widthFactor: (it.value / maxV).clamp(0.02, 1.0),
                          child: Container(height: 12, decoration: BoxDecoration(color: it.color == Colors.transparent ? (color ?? Pal.chartBlue) : it.color, borderRadius: BorderRadius.circular(6))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 118,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(fmt(it.value), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Short month names in the current language.
String shortMonth(int month) {
  const sw = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des'];
  const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return (appIsEnglish ? en : sw)[month - 1];
}
