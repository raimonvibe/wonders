import 'package:flutter/material.dart';

/// The explanatory line under a control.
///
/// A `ListTile` carrying only a `subtitle` was doing this job on both settings
/// surfaces, and it leaves the gap where the title would have gone — a visible
/// band of nothing between the speed slider and the sentence explaining it,
/// which reads as a rendering fault rather than as spacing. Material's
/// supporting text is body copy in the muted colour, set close to the control
/// it belongs to, so that is what this is.
///
/// Lives here rather than in either settings file because both need it and they
/// must not drift apart: the same sentence should sit the same distance from
/// its control whether it is read on the More tab or in the mini player's sheet.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
        ),
      ),
    );
  }
}

/// How tall a fixed-extent grid tile has to be at the reader's chosen text size.
///
/// A grid with a hard-coded `mainAxisExtent` is a RenderFlex overflow waiting
/// for somebody to turn their system font up. The wonders' era picker was
/// already overflowing at the *default* size: "Acts and the early church" wraps
/// to two lines inside a 150pt tile, and Card's own 4pt margin took another
/// eight off the height before the padding was subtracted.
///
/// Measuring instead of guessing costs one call and means the accessibility
/// text sizes work rather than striping the screen yellow and black.
double gridTileExtent(
  BuildContext context, {
  /// Lines of body text the tile shows. Pair with a matching `maxLines` on the
  /// Text itself, or a longer label will still find a third line to overflow
  /// into.
  required int titleLines,

  /// Lines of the smaller secondary text underneath, if any.
  int subtitleLines = 0,

  /// Everything that is not text: the tile's own padding, plus any Card margin.
  double chrome = 0,

  /// A floor, for grids whose tiles are mostly air by design — a grid of
  /// chapter numbers looks wrong collapsed to the height of one digit. The
  /// tile grows past this when the text needs it to and never shrinks below.
  double minimum = 0,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  final text = Theme.of(context).textTheme;

  // google_fonts leaves `height` null on most styles, and Flutter then uses the
  // font's own metrics — near enough 1.45 for Inter at these sizes, and erring
  // high here only costs a pixel of slack.
  double lineOf(TextStyle? style, double fallbackSize) =>
      scaler.scale(style?.fontSize ?? fallbackSize) * (style?.height ?? 1.45);

  final title = lineOf(text.bodyMedium, 14) * titleLines;
  final subtitle = subtitleLines == 0
      ? 0.0
      : lineOf(text.bodySmall, 12) * subtitleLines + 2;

  final needed = title + subtitle + chrome;
  return needed < minimum ? minimum : needed;
}
