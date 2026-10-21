import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart' hide Text;

import '../../core/theme.dart';
import '../../core/tr_text.dart';
import '../../utils/formatters.dart';
import 'full_width_scroll.dart';
import 'pagination_bar.dart';

/// The one table of the admin panel's reports: click a heading to sort, pages of 25/50/100 rows, zebra
/// rows with a hover highlight, right-aligned money in tabular figures, coloured status badges and a
/// TOTAL row that stays at the bottom of every page.
///
/// [rows] hold raw values (String / num / null); `double` is shown as money without the "TZS" prefix.
/// When the first heading is "No" / "SN" that column is a running number: it is renumbered after sorting.
class AppDataGrid extends StatefulWidget {
  const AppDataGrid({
    super.key,
    required this.headers,
    required this.rows,
    this.totals,
    this.numeric = const {},
    this.badges = const {},
    this.pageSize = 25,
    this.fontSize = 11.5,
  });

  final List<String> headers;
  final List<List<Object?>> rows;
  final List<Object?>? totals;

  /// Column indexes (counted with "No") that are right-aligned numbers.
  final Set<int> numeric;

  /// Cell text -> badge colour (e.g. 'Linaendelea': Colors.orange).
  final Map<String, Color> badges;
  final int pageSize;
  final double fontSize;

  @override
  State<AppDataGrid> createState() => _AppDataGridState();
}

class _AppDataGridState extends State<AppDataGrid> {
  int? _sortCol;
  bool _asc = true;
  int _page = 0;
  late int _size = widget.pageSize;

  bool get _hasIndex => widget.headers.isNotEmpty && (widget.headers.first == 'No' || widget.headers.first == 'SN');

  List<List<Object?>> _sorted() {
    final rows = List<List<Object?>>.from(widget.rows);
    final c = _sortCol;
    if (c == null) return rows;
    int cmp(Object? a, Object? b) {
      if (a is num && b is num) return a.compareTo(b);
      return '${a ?? ''}'.toLowerCase().compareTo('${b ?? ''}'.toLowerCase());
    }

    // empty values always go last, whichever the direction
    rows.sort((x, y) {
      final a = c < x.length ? x[c] : null, b = c < y.length ? y[c] : null;
      final ea = a == null || (a is String && a.isEmpty), eb = b == null || (b is String && b.isEmpty);
      if (ea || eb) return ea == eb ? 0 : (ea ? 1 : -1);
      return _asc ? cmp(a, b) : cmp(b, a);
    });
    return rows;
  }

  String _text(Object? v) => v == null ? '' : (v is double ? formatTZS(v).replaceFirst('TZS ', '') : '$v');

  Widget _cell(Object? v, int col, {bool bold = false}) {
    final style = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
      fontFeatures: widget.numeric.contains(col) ? const [FontFeature.tabularFigures()] : null,
    );
    final s = _text(v);
    final badge = widget.badges[s];
    if (badge != null && !bold) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: Pal.tint(badge), borderRadius: BorderRadius.circular(20)),
        child: Text(s, style: TextStyle(fontSize: widget.fontSize - 1, fontWeight: FontWeight.w700, color: Pal.fg(badge is MaterialColor ? badge.shade700 : badge))),
      );
    }
    return Text(s, style: style);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted();
    final total = sorted.length;
    final page = clampPage(_page, total, _size);
    final slice = pageSlice(sorted, page, _size);
    final offset = page * _size;

    WidgetStateProperty<Color?> shade(int i) => WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return Pal.tint(Colors.blue);
          return i.isOdd ? Pal.surfaceAlt.withOpacity(Pal.dark ? 0.45 : 0.55) : null;
        });

    DataRow row(List<Object?> r, int i) => DataRow(
          color: shade(i),
          cells: [
            for (var c = 0; c < widget.headers.length; c++)
              DataCell(_cell(_hasIndex && c == 0 ? offset + i + 1 : (c < r.length ? r[c] : null), c)),
          ],
        );

    final totals = widget.totals;
    return Container(
      decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FullWidthScroll(
            child: DataTable(
              sortColumnIndex: _sortCol,
              sortAscending: _asc,
              headingRowHeight: 42,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 44,
              columnSpacing: 24,
              horizontalMargin: 16,
              dividerThickness: 0.6,
              headingRowColor: WidgetStatePropertyAll(Pal.surfaceAlt),
              columns: [
                for (var i = 0; i < widget.headers.length; i++)
                  DataColumn(
                    numeric: widget.numeric.contains(i),
                    label: Text(widget.headers[i], style: TextStyle(fontSize: widget.fontSize - 0.5, fontWeight: FontWeight.w800, color: Pal.textSecondary)),
                    onSort: (_hasIndex && i == 0)
                        ? null
                        : (col, asc) => setState(() {
                              _sortCol = col;
                              _asc = asc;
                              _page = 0;
                            }),
                  ),
              ],
              rows: [
                for (var i = 0; i < slice.length; i++) row(slice[i], i),
                if (totals != null)
                  DataRow(
                    color: WidgetStatePropertyAll(Pal.tint(Colors.blue)),
                    cells: [for (var c = 0; c < widget.headers.length; c++) DataCell(_cell(c < totals.length ? totals[c] : null, c, bold: true))],
                  ),
              ],
            ),
          ),
          PaginationBar(
            total: total,
            page: page,
            pageSize: _size,
            onPageChanged: (p) => setState(() => _page = p),
            onPageSizeChanged: (s) => setState(() {
              _size = s;
              _page = 0;
            }),
          ),
        ],
      ),
    );
  }
}
