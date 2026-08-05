import 'package:flutter/material.dart';

/// A header row (title + action buttons) that adapts to any screen width
/// using LayoutBuilder: side-by-side on wide screens, stacked with wrapping
/// actions on narrow ones. Used across Dashboard/Settings/Registration
/// screens so headers never overflow horizontally on small viewports.
class ResponsiveHeaderBar extends StatelessWidget {
  const ResponsiveHeaderBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.breakpoint = 640,
  });

  final Widget title;
  final Widget? subtitle;
  final List<Widget> actions;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < breakpoint;

      final titleBlock = subtitle == null
          ? title
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [title, const SizedBox(height: 4), subtitle!],
            );

      if (isNarrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titleBlock,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: titleBlock),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 12),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: actions),
          ],
        ],
      );
    });
  }
}
