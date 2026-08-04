import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/wonder.dart';
import '../../theme/palette.dart';

/// The widget that exists only to become a PNG.
///
/// This is deliberately not the on-screen card. That one scrolls, sizes to the
/// phone, and carries navigation chrome; this one is a fixed 1080×1350 (4:5)
/// composition — the aspect Instagram and WhatsApp will not crop — laid out to
/// be read in someone else's feed.
///
/// The content rule, and it is a hard one: **only [Wonder.quote] and
/// [Wonder.quoteRef] go on the image.** Those are verbatim World English Bible
/// text, public domain, and checked by `npm run validate:wonders`. The
/// `whatHappened` and `hopeMeaning` prose is ours, not scripture, and putting
/// it in the same frame as a reference invites someone to read it as the Bible
/// saying it.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.wonder,
    required this.siteLabel,
  });

  /// The export size, in logical pixels. Captured at pixelRatio 3 for a
  /// 3240×4050 PNG, which stays crisp on any phone it lands on.
  static const Size exportSize = Size(1080, 1350);

  final Wonder wonder;

  /// The only branding on the image, e.g. "bible-wonders-seven.vercel.app".
  final String siteLabel;

  @override
  Widget build(BuildContext context) {
    // The palette follows the testament, so a set of shares reads as a set.
    final palette =
        wonder.testament == Testament.old ? Palette.pine : Palette.ocean;

    final quote = wonder.quote;
    final quoteRef = wonder.quoteRef;
    assert(
      quote != null && quoteRef != null,
      'ShareCard needs a quote; guard with Wonder.isShareable first.',
    );

    return SizedBox(
      width: exportSize.width,
      height: exportSize.height,
      // Every line of this card came out with a yellow double underline
      // through it on a real device, and not in the golden, which is the
      // combination that makes a bug live a long life.
      //
      // MaterialApp wraps its subtree in a DefaultTextStyle carrying Flutter's
      // `_errorTextStyle` — red monospace with a yellow double underline,
      // labelled "fallback style; consider putting your text in a Material".
      // Material normally overrides it, and every screen in this app is inside
      // one. This card is not: ShareService mounts it in the *root* overlay,
      // which sits above every Scaffold, so the fallback arrived with nothing
      // to replace it. The styles below set colour, size and family, so those
      // won all three; not one of them mentions `decoration`, so the underline
      // came through untouched.
      //
      // The golden test never saw it because it mounts the card with no
      // MaterialApp at all, where `DefaultTextStyle.fallback()` applies and has
      // no decoration. The test was kinder than the world.
      //
      // Setting it here rather than in ShareService is what stops that
      // happening again: this card carries its own typography and no longer
      // depends on what it is mounted inside.
      child: DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: palette.pageGradient),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(96, 110, 96, 84),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 180,
                    height: 0.8,
                    color: Palette.accent.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 8),

                // The scripture, given every pixel that is going spare and then
                // set at the largest size that fits it.
                //
                // This was a `Flexible` above a `Spacer`, which are both flex 1,
                // so the two split the slack half and half however much of it the
                // quote actually needed — the quote got 50% whatever it was. It
                // survived only because the sizes below were tuned against a
                // typeface that was not being used: with real Merriweather, which
                // is wider, Exodus 14:21 lost its last line and a half under the
                // rule. On a picture whose entire content rule is "verbatim
                // scripture and nothing else", a quote sliced mid-sentence is the
                // worst thing this file could produce, and it produces it into a
                // PNG that goes out to other people.
                //
                // Expanded, and no Spacer: the quote owns the slack, and the
                // attribution gathers at the foot of the card.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        quote ?? '',
                        style: _quoteStyle(
                          _quoteSizeFor(quote ?? '', box.biggest),
                        ).copyWith(color: palette.shade50),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),
                Container(width: 96, height: 3, color: Palette.accent),
                const SizedBox(height: 32),

                Text(
                  quoteRef ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 38,
                    fontWeight: FontWeight.w600,
                    color: palette.shade200,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  wonder.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 34,
                    color: palette.shade300,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 40),
                // Expanded rather than a Spacer between the two: this canvas is
                // fixed, so a site label that does not fit has nowhere to go and
                // Flutter would paint its overflow stripes straight into the
                // exported PNG. The credit is the one that must never be cut.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        siteLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          color: palette.shade300.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text(
                      'World English Bible',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        color: palette.shade400.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The face and leading the quote is set in, at a given size.
  ///
  /// Stated once so the size chosen by [_quoteSizeFor] is chosen by measuring
  /// the very style that is then painted. Measuring one style and painting
  /// another is how a fitted layout stops fitting.
  static TextStyle _quoteStyle(double size) =>
      GoogleFonts.merriweather(fontSize: size, height: 1.55);

  /// The largest size at which the whole quote fits [box].
  ///
  /// This used to step down by character count, which is a guess twice over: it
  /// assumes every character is the same width — "WWWW" and "iiii" are not —
  /// and it assumes a particular typeface, which is exactly the assumption that
  /// broke when the faces stopped being whatever the network happened to
  /// deliver. Laying the text out and asking how tall it came to costs six
  /// TextPainter passes on a picture that is built once, by hand, when somebody
  /// presses Share.
  static double _quoteSizeFor(String quote, Size box) {
    // 68 is the size a short quote looks right at; below 30 the verse is
    // smaller than the reference under it and the composition has failed at
    // something other than fitting.
    for (var size = 68.0; size > 30; size -= 2) {
      final painter = TextPainter(
        text: TextSpan(text: quote, style: _quoteStyle(size)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: box.width);

      final fits = painter.height <= box.height;
      painter.dispose();
      if (fits) return size;
    }
    return 30;
  }
}
