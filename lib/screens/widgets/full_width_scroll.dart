import 'package:flutter/material.dart';

/// Horizontal scroller for a wide table that makes the table AT LEAST as wide as
/// the available space (so it fills the whole card on large screens) while still
/// scrolling sideways when its columns need more room on small screens.
class FullWidthScroll extends StatelessWidget {
  const FullWidthScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: child,
        ),
      ),
    );
  }
}
