import 'package:flutter/material.dart';

import 'palette.dart';

/// The small caps rule over a group.
///
/// The wonder card had this as a private widget and used it five times; the
/// home screen and the settings list wanted the same thing and had nothing to
/// reach for, so one grew headings in `titleLarge` and the other grew none at
/// all. It is the quietest way to say "these belong together" — quiet enough to
/// use on a screen whose real content is a list — and it carries a `header`
/// semantic, which is what lets a screen reader jump between the groups instead
/// of walking every chip.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, required this.palette});

  final String text;
  final Palette palette;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: palette.shade300,
          ),
        ),
      );
}

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

/// The reader's chosen size, composed with the one the platform already asked
/// for.
///
/// The reading size used to be applied by hand, by the one screen that thought
/// to: `passage_view` multiplied its own font sizes by it and nothing else did.
/// So a reader who set 160% got 160% scripture in the Bible tab and a wonder
/// card still at 100% — including the verse quoted at the top of it, which is
/// the same scripture, set the same way, one tap apart. Every screen added
/// after that would have had to remember, and screens do not remember.
///
/// A [TextScaler] is the mechanism Flutter already has for this: put one in the
/// [MediaQuery] at the root and every `Text` beneath it obeys, whether or not
/// its author knew the setting existed.
///
/// [platform] is whatever the device's own accessibility setting resolved to,
/// and it is composed rather than replaced. Both are real requests — one made
/// in the system settings, one made in this app — and a reader who has asked
/// for large text everywhere and larger scripture here means both. Composing by
/// scaling the size *before* handing it on is what `passage_view` was already
/// doing when it wrote `18 * scale` inside a `Text` the platform then scaled
/// again, so the reader's existing size comes through unchanged.
class ReadingScaler extends TextScaler {
  const ReadingScaler(this.platform, this.reading);

  /// The device's own text size.
  final TextScaler platform;

  /// The reader's, from the slider on the More tab. 0.85 to 1.6.
  final double reading;

  @override
  double scale(double fontSize) => platform.scale(fontSize * reading);

  // Deprecated on TextScaler itself, in favour of the non-linear scale()
  // above, but still abstract — so it has to be answered, and answered
  // consistently with scale() for anything old enough to ask.
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => platform.textScaleFactor * reading;

  // MediaQuery compares its data to decide whether the subtree has to be
  // rebuilt. Without these two, moving the slider would build a new scaler that
  // compared equal to the old one and nothing on screen would change.
  @override
  bool operator ==(Object other) =>
      other is ReadingScaler &&
      other.platform == platform &&
      other.reading == reading;

  @override
  int get hashCode => Object.hash(platform, reading);
}

/// The side margins a column of text should have, given the room it is in.
///
/// A line of prose has a length past which it stops being readable, and it is
/// shorter than people expect. The typographic rule of thumb — and the one the
/// accessibility guidance repeats — is 50 to 75 characters, with WCAG naming 80
/// as the ceiling for Latin scripts; past that the eye loses the start of the
/// next line on the way back from the end of this one, and reading turns into
/// finding your place.
///
/// On a phone this never bites. 400 pt of screen at 18 pt Merriweather is about
/// 36 characters — comfortably inside the 30–40 that suits a hand-held column.
/// It bites on everything wider: a 10-inch tablet runs to about 78 characters
/// and a landscape foldable well past 100, which is the shape this app is
/// hardest to read in and the one nobody tests. Scripture is exactly the kind
/// of text people read for half an hour at a time, so it is worth the margin.
///
/// Returns the horizontal inset, never below [minimum], so the phone case comes
/// out precisely as it did before.
double readingGutter(
  double available, {
  /// The size the text is actually set at, the reader's own scale included.
  required double fontSize,

  /// The gutter a narrow screen keeps.
  double minimum = 20,
}) {
  // Characters per line ≈ width ÷ (fontSize × average advance). Merriweather
  // and Inter both average near 0.52 em across lower-case text, so 66
  // characters — the middle of the range — is a column about 34 times the font
  // size wide.
  const idealCharacters = 66;
  const averageAdvance = 0.52;

  final ideal = idealCharacters * averageAdvance * fontSize;
  final gutter = (available - ideal) / 2;
  return gutter < minimum ? minimum : gutter;
}

/// The side margins a column of *controls* should have, given the room it is in.
///
/// [readingGutter] is the rule for prose, and the wonder card and the passage
/// both obey it. The home screen is not prose — it is a heading, a resume card,
/// four chips, a search box and a list of rows — so it was left full-bleed, and
/// on a tablet in landscape that turns out to be its own kind of unreadable. A
/// search field 1,270 pt wide does not look generous, it looks unfinished; a
/// list row whose text ends a quarter of the way across leaves the eye to cross
/// three quarters of a screen of nothing to reach the next one.
///
/// Controls tolerate more width than prose does — a chip is not read left to
/// right for half an hour — so the ceiling is wider than the 66-character
/// measure, wide enough that the catalog can run in two columns rather than one
/// stretched one. Past it the extra width becomes margin, which is the thing
/// that makes a wide screen look composed rather than merely large.
///
/// [minimum] is 0 rather than 20 because every caller already carries its own
/// 16 pt padding: this is the gutter *outside* that, so a phone comes out
/// exactly as it did before.
double contentGutter(
  double available, {
  /// The widest the column of controls is allowed to get.
  double ideal = contentIdeal,
  double minimum = 0,
}) {
  final gutter = (available - ideal) / 2;
  return gutter < minimum ? minimum : gutter;
}

/// The widest a column of controls is allowed to get.
///
/// Wide enough for two catalog columns at a comfortable width, narrow enough
/// that a 13-inch tablet in landscape keeps a visible margin either side.
const double contentIdeal = 880;

/// Two catalog columns need this much room between the gutters.
///
/// Below it the pair would be narrower than a phone's single column, which
/// trades one kind of awkward for another: a wonder's title and its reference
/// both wrapping in a 280 pt slot is worse than one column with room to spare.
const double catalogTwoColumnFrom = 640;

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

  final needed = title + subtitle + chrome + _slack;
  return needed < minimum ? minimum : needed;
}

/// Two pixels of nothing, on purpose.
///
/// Working from the theme's nominal metrics gets within a fraction of a pixel
/// of what the text engine actually lays out, and a fraction is all it takes:
/// the era grid overflowed by 0.2 pt at a text size of 1.3, which is not a
/// rounding error to look at but the full yellow-and-black stripe across four
/// tiles. The measurement is a prediction of the engine's arithmetic, not a
/// copy of it, so it is rounded up rather than trusted to the decimal.
const _slack = 2.0;
