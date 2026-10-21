import 'package:flutter/material.dart' hide Text;

import '../../core/tr_text.dart';
import '../../core/translations.dart';
import '../../core/theme.dart';

/// Clamp [page] (0-based) so it always points at an existing page.
int clampPage(int page, int total, int pageSize) {
  if (total <= 0) return 0;
  final last = (total - 1) ~/ pageSize;
  return page < 0 ? 0 : (page > last ? last : page);
}

/// The slice of [all] shown on [page] (0-based).
List<T> pageSlice<T>(List<T> all, int page, int pageSize) {
  if (all.isEmpty) return const [];
  final start = clampPage(page, all.length, pageSize) * pageSize;
  final end = start + pageSize > all.length ? all.length : start + pageSize;
  return all.sublist(start, end);
}

/// Footer for any table: rows-per-page selector, "1 - 25 of 340", first/prev/
/// next/last. Rendering only one page of rows at a time is what keeps big
/// tables (hundreds of employees, long audit logs) fast.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.pageSizes = const [10, 25, 50, 100],
  });

  final int total;
  final int page; // 0-based
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final List<int> pageSizes;

  @override
  Widget build(BuildContext context) {
    final pages = total == 0 ? 1 : ((total - 1) ~/ pageSize) + 1;
    final current = clampPage(page, total, pageSize);
    final from = total == 0 ? 0 : current * pageSize + 1;
    final to = total == 0 ? 0 : ((current + 1) * pageSize > total ? total : (current + 1) * pageSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Pal.border)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        spacing: 16,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rekodi kwa ukurasa:', style: TextStyle(fontSize: 11, color: Pal.textSecondary)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: pageSizes.contains(pageSize) ? pageSize : pageSizes.first,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: pageSizes
                    .map((s) => DropdownMenuItem(value: s, child: Text('$s', style: const TextStyle(fontSize: 11))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onPageSizeChanged(v);
                },
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$from - $to kati ya $total', style: TextStyle(fontSize: 11, color: Pal.textSecondary)),
              const SizedBox(width: 8),
              IconButton(
                tooltip: tr('Ukurasa wa kwanza'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.first_page, size: 18),
                onPressed: current > 0 ? () => onPageChanged(0) : null,
              ),
              IconButton(
                tooltip: tr('Ukurasa uliopita'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left, size: 18),
                onPressed: current > 0 ? () => onPageChanged(current - 1) : null,
              ),
              Text('Ukurasa ${current + 1} / $pages', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              IconButton(
                tooltip: tr('Ukurasa unaofuata'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right, size: 18),
                onPressed: current < pages - 1 ? () => onPageChanged(current + 1) : null,
              ),
              IconButton(
                tooltip: tr('Ukurasa wa mwisho'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.last_page, size: 18),
                onPressed: current < pages - 1 ? () => onPageChanged(pages - 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
