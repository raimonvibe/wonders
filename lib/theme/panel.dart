import 'package:flutter/material.dart';

import 'palette.dart';

/// The lifted panel: a pull quote, a reflection, the reading-size sample.
///
/// Three places were building this by hand — the same gradient and the same
/// hairline, at radius 16 in one and 14 in the other two — so a card scrolled
/// from its quote to its reflection changed corner on the way, and the sample
/// on the More tab was a third shape again. Small enough that nobody would
/// report it and exactly the kind of thing that makes a screen feel assembled
/// rather than designed.
///
/// The radius is the `Card` theme's now, stated once. The one difference that
/// is meant swaps the hairline for a rule down the left edge: [accent] is how
/// "sit with this" is told apart from "this is a quotation", and it is the same
/// left rule a kept verse and a spoken verse wear, so the language holds across
/// the app.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 16),
    this.accent = false,
  });

  final Palette palette;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Trade the hairline for the accent rule down the left edge.
  final bool accent;

  /// Matches `cardTheme` in [AppTheme], so a panel and a card sitting in the
  /// same column are the same shape.
  static const radius = 16.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: palette.cardGradient,
        borderRadius: BorderRadius.circular(radius),
        border: accent
            ? const Border(left: BorderSide(color: Palette.accent, width: 3))
            : Border.all(color: palette.shade600.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }
}
