import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'palette.dart';

/// Every app bar title in the app: gold-ruled, wrapping, and measured.
///
/// ## Why a plain `Text` was not enough
///
/// [ReadingScaler] puts the reader's own size — the slider on the More tab, up
/// to 1.6 — into the MediaQuery at the root of the app, composed with whatever
/// the device's accessibility setting already asked for. Everything obeys it,
/// including these titles: on a phone set to 1.3 with the slider at 1.6, a 20 pt
/// title is laid out at 41 pt.
///
/// A bar is 56 pt tall and holds one line, so the only thing a title can do when
/// it does not fit is disappear. And these titles are not decoration — the
/// wonder card's bar carries the *name of the wonder*, which on a 360 pt phone
/// came out as "Abimelech's Household …" at the ordinary text size, before any
/// accessibility setting was involved at all. A back button and two actions
/// leave that title 176 pt to say twenty-eight characters in.
///
/// ## The rule
///
/// One per line, each as long as the words on that line — not one bar under the
/// block. A single rule under a wrapped title underlines the last line and
/// stretches past it to the width of the longest, which reads as a rule that
/// missed rather than as a mark under the words.
///
/// Drawing per line means the text cannot simply be stacked in a `Column`: it is
/// one paragraph, and only the text engine knows where it broke. So the lines
/// are laid out once, `computeLineMetrics` is asked where each one starts and
/// how wide it came out, and the rules are painted at those positions over the
/// real `Text` — which stays a real `Text`, so the whole title still reaches the
/// semantics tree whatever the rules do.
///
/// A wrapped title is set on [_lineHeight] leading rather than the font's own,
/// because a rule under line one lands where line two's ascenders would be. A
/// title that fits on one line keeps the natural leading, so the bar it sits in
/// is exactly [kToolbarHeight] and nothing has moved on the screens — most of
/// them — whose titles are short.
class AppBarTitle extends StatelessWidget {
  const AppBarTitle(this.text, {super.key, this.actions = 0});

  final String text;

  /// The most actions this bar ever shows.
  ///
  /// Only the height calculation needs it: this is width the title does *not*
  /// get, and it is what decides where the text breaks. Several bars show one
  /// action or two depending on what is on screen — pass the larger. Reserving
  /// room that turns out to be free costs a few points of bar; reserving too
  /// little is what clips.
  final int actions;

  /// How thick a rule is drawn. Two points is a hairline that the sheen has
  /// nowhere to happen in; four starts to read as a highlighter.
  static const _rule = 3.0;

  /// How far below the baseline a rule sits, in ems.
  ///
  /// Playfair's descenders reach 0.256 em, so this clears them by about five
  /// points at the default size — which is the gap the rule was drawn at when it
  /// was a `SizedBox` in a `Column`, kept so nothing about the look changed when
  /// the drawing did.
  static const _ruleDrop = 0.50;

  /// The leading a *wrapped* title is set on, in ems.
  ///
  /// It has to clear Playfair's ascent (1.082 em) plus a rule sitting at
  /// [_ruleDrop], or line one's rule strikes line two. 1.9 leaves about three
  /// points of air at the smallest size this is ever drawn at, and more at every
  /// larger one, because the rule's thickness is fixed in points while the text
  /// around it grows.
  static const _lineHeight = 1.9;

  /// The breathing room above and below, once the bar has to grow.
  static const _padding = 16.0;

  /// The most a title will grow by, whatever the reader has asked for.
  ///
  /// This is not a number of ours. `AppBar` wraps its own title in
  /// `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.34)` — see
  /// `_kMaxTitleTextScaleFactor` in the framework's app_bar.dart — so 1.34 is
  /// the scale a title is painted at no matter what anyone else decides.
  ///
  /// Matching it is the whole point. [toolbarHeightFor] runs *outside* the bar,
  /// where the reader's full scale is still in force; the title is built
  /// *inside* it, where the framework has already cut it to 1.34. Measuring at
  /// one scale and painting at another is how a bar came out sized for two lines
  /// while the title took four — 177 points of room for 211 points of text, with
  /// the overflow landing on the gold.
  ///
  /// The reading slider is not being ignored, only the bar is: it is chrome,
  /// glanced at rather than read, and every screen's body still scales without a
  /// ceiling.
  static const _maxScale = 1.34;

  /// The most of the screen a bar may spend on its title.
  ///
  /// Something has to bound this: a bar past about a third of the height has
  /// stopped being chrome and become the page. Three tenths is what it takes to
  /// carry the longest title in the catalog — "Amalek Defeated while Moses'
  /// Hands Are Held Up", forty-six characters in the 176 pt a 360 pt phone
  /// leaves after a back button and two actions — whole, at every size, which is
  /// five lines at the [_maxScale] ceiling.
  ///
  /// That case is the one this is sized for and it is the only one that reaches
  /// it: it needs a title in the top handful for length, the reading slider up,
  /// a narrow phone and both actions on screen at once. Every other title in the
  /// app leaves the bar at [kToolbarHeight] or one line above it.
  ///
  /// Past the budget the title ellipsises, which is the honest failure: it is
  /// Material's own answer for a title too long to show, and the untruncated
  /// string still goes to the semantics tree, so a screen reader hears all of it
  /// either way.
  static const _maxBarFraction = 0.36;

  /// A hard cap on lines, under the height budget.
  ///
  /// A short screen in landscape has so little height that the fraction above
  /// would allow one line; a tall one would allow eight, and eight lines of app
  /// bar is not a title, it is a paragraph nobody asked to read.
  static const _maxLines = 5;

  /// `AppBar`'s own inset either side of the title, i.e.
  /// `NavigationToolbar.kMiddleSpacing`.
  static const _titleSpacing = NavigationToolbar.kMiddleSpacing;

  /// What one action reserves. `IconButton` holds its 48 pt tap target however
  /// big the glyph inside it is — see the note on [speechIconSize].
  static const _actionWidth = 48.0;

  /// What the back button reserves — `AppBar`'s own `_kLeadingWidth`, which is
  /// [kToolbarHeight].
  static const _leadingWidth = kToolbarHeight;

  /// Width held back from the estimate.
  ///
  /// Zero, and deliberately so. This was 8, on the reasoning that the two
  /// failures are asymmetric — guess wide and the gold falls off the bottom,
  /// guess narrow and the bar is merely a little tall. That reasoning was
  /// sound and the remedy was still wrong: on a 320 pt phone at the scale
  /// ceiling, "Wonders and Hope" measures 233 points and the estimate offered
  /// 232, so the bar reserved two lines and painted one — 125 points of chrome
  /// around 46 points of title.
  ///
  /// A margin was standing in for a real mismatch, which was [_maxScale]
  /// disagreeing with the framework's. With that fixed, [_widthFor] is
  /// `NavigationToolbar`'s own arithmetic at the same scale the bar paints at,
  /// and there is nothing left for a margin to protect against.
  static const _safety = 0.0;

  /// The reader's size, held to [_maxScale].
  static TextScaler _scalerOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).clamp(maxScaleFactor: _maxScale);

  static TextStyle _styleOf(BuildContext context, {required bool wrapped}) {
    final style = Theme.of(context).appBarTheme.titleTextStyle ??
        const TextStyle(fontSize: 20);
    return wrapped ? style.copyWith(height: _lineHeight) : style;
  }

  static double _fontSizeOf(BuildContext context) =>
      _scalerOf(context).scale(_styleOf(context, wrapped: false).fontSize ?? 20);

  /// The width the title is left with once the bar's furniture has taken its
  /// share.
  ///
  /// The arithmetic is `NavigationToolbar`'s own — leading, trailing, and the
  /// middle spacing twice — and whether there is a back button is asked with
  /// `impliesAppBarDismissal`, which is the very getter `AppBar` uses to decide
  /// whether to draw one. Asking a different question, as this did with
  /// `canPop`, is how the estimate and the bar come to disagree.
  ///
  /// The window's width, not the bar's, which cannot be known before the bar is
  /// laid out. On a wide screen the nav rail has already taken 80 of those
  /// points, so this over-estimates the room — harmlessly, because a screen that
  /// wide fits any of these titles on one line.
  static double _widthFor(BuildContext context, int actions) {
    final pushed = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final width = MediaQuery.sizeOf(context).width -
        (pushed ? _leadingWidth : 0) -
        _actionWidth * actions -
        _titleSpacing * 2 -
        _safety;
    return math.max(width, 0);
  }

  static TextPainter _painterFor(
    BuildContext context,
    String text,
    int maxLines, {
    required bool wrapped,
  }) =>
      TextPainter(
        text: TextSpan(text: text, style: _styleOf(context, wrapped: wrapped)),
        textDirection: Directionality.of(context),
        textScaler: _scalerOf(context),
        maxLines: maxLines,
      );

  /// How many lines this title may take, given the room the screen can spare.
  ///
  /// One line is measured rather than assumed, so the answer comes from the
  /// typeface's real metrics at the reader's real size. Measured on the wrapped
  /// leading, which is the leading a title that reaches two lines will be set
  /// on and therefore the one the budget has to be spent in.
  static int _linesFor(BuildContext context, String text) {
    final one = _painterFor(context, text, 1, wrapped: true)..layout();
    final line = one.height;
    one.dispose();
    if (line <= 0) return 1;

    final budget =
        MediaQuery.sizeOf(context).height * _maxBarFraction - _padding;
    return (budget ~/ line).clamp(1, _maxLines);
  }

  /// Lays the title out in [maxWidth] and reports what the bar has to hold: the
  /// paragraph, plus however far the last line's rule falls below it.
  static ({double height, double width, List<ui.LineMetrics> lines}) _measure(
    BuildContext context,
    String text,
    double maxWidth, {
    int? maxLines,
  }) {
    final cap = maxLines ?? _linesFor(context, text);

    // Which leading to use is itself decided by laying the text out, because
    // `height` changes how tall a line is and not where it breaks. Natural
    // leading first; if that came to more than one line, again on [_lineHeight].
    var painter = _painterFor(context, text, cap, wrapped: false)
      ..layout(maxWidth: maxWidth);
    var lines = painter.computeLineMetrics();
    if (lines.length > 1) {
      painter.dispose();
      painter = _painterFor(context, text, cap, wrapped: true)
        ..layout(maxWidth: maxWidth);
      lines = painter.computeLineMetrics();
    }

    final paragraph = painter.height;
    // `width` is the longest line, so the block is exactly as wide as the words
    // and the bar's own alignment does the rest. Rounded up because the `Text`
    // is then laid out at this width and a fraction of a point short of what the
    // engine measured is a line break that was not there a moment ago.
    final width = painter.width.ceilToDouble();
    painter.dispose();

    final drop = _fontSizeOf(context) * _ruleDrop;
    final overhang = lines.isEmpty
        ? 0.0
        : math.max(0.0, lines.last.baseline + drop + _rule - paragraph);

    return (height: paragraph + overhang, width: width, lines: lines);
  }

  /// The bar height that keeps this title whole. Pass it to `AppBar`'s
  /// `toolbarHeight`, with the same arguments the widget itself is given.
  ///
  /// [kToolbarHeight] until the text needs more, so at the sizes most people
  /// read at every bar in the app is exactly the standard one.
  static double toolbarHeightFor(
    BuildContext context,
    String text, {
    int actions = 0,
  }) {
    final measured = _measure(context, text, _widthFor(context, actions));
    return math.max(kToolbarHeight, measured.height + _padding);
  }

  @override
  Widget build(BuildContext context) {
    // The real width this time, not the estimate — so the rules are painted
    // under the lines as they actually broke.
    return LayoutBuilder(
      builder: (context, box) {
        final measured = _measure(context, text, box.maxWidth);
        final wrapped = measured.lines.length > 1;

        return SizedBox(
          width: measured.width,
          height: measured.height,
          child: CustomPaint(
            foregroundPainter: _Rules(
              lines: measured.lines,
              drop: _fontSizeOf(context) * _ruleDrop,
            ),
            child: Text(
              text,
              style: _styleOf(context, wrapped: wrapped),
              maxLines: measured.lines.length,
              overflow: TextOverflow.ellipsis,
              textScaler: _scalerOf(context),
            ),
          ),
        );
      },
    );
  }

  // A note on what is *not* here, because it looks like it should be.
  //
  // The obvious safeguard is for the title to check the height it was actually
  // given and step down a line until it fits, so a wrong [toolbarHeightFor]
  // could never cut it off. It cannot be written: `AppBar` wraps its title in
  // `_AppBarTitleBox`, whose `performLayout` lays the child out with
  // `maxHeight: double.infinity` and only then constrains the *box* — see
  // app_bar.dart. A `LayoutBuilder` in here is handed an unbounded height and
  // has no way to learn the bar's.
  //
  // What keeps the two in step is therefore upstream, and all of it is:
  // the scale matches the framework's own 1.34 ceiling, the width is
  // `NavigationToolbar`'s own arithmetic, and `main` waits for the typefaces so
  // nothing is measured in a face it will not be painted in. See the note in
  // app.dart for why there is no runtime safeguard under those.
}

/// The gold under the words — one rule per line, each the width of its own line.
///
/// Each gets its own shader over its own rectangle, so a short line carries the
/// whole sheen rather than a slice of one gradient stretched across the block.
/// That is what keeps two rules under a wrapped title reading as a pair of marks
/// rather than as one mark that broke.
class _Rules extends CustomPainter {
  const _Rules({required this.lines, required this.drop});

  final List<ui.LineMetrics> lines;

  /// How far below each baseline the rule's top edge sits.
  final double drop;

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      // A blank line has nothing to underline. It happens on a title that
      // wrapped at an explicit break, and a rule of zero width still paints a
      // visible dot at this radius.
      if (line.width <= 0) continue;

      final rect = Rect.fromLTWH(
        line.left,
        line.baseline + drop,
        line.width,
        AppBarTitle._rule,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(AppBarTitle._rule / 2),
        ),
        Paint()..shader = Palette.goldSheen.createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_Rules old) {
    if (old.drop != drop || old.lines.length != lines.length) return true;
    for (var i = 0; i < lines.length; i++) {
      if (old.lines[i].left != lines[i].left ||
          old.lines[i].width != lines[i].width ||
          old.lines[i].baseline != lines[i].baseline) {
        return true;
      }
    }
    return false;
  }
}
