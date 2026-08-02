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

              // The scripture. Flexible so a long quote shrinks the gap below
              // rather than overflowing a fixed-height canvas.
              Flexible(
                child: Text(
                  quote ?? '',
                  style: GoogleFonts.merriweather(
                    fontSize: _quoteSizeFor(quote ?? ''),
                    height: 1.55,
                    color: palette.shade50,
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

              const Spacer(),
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
    );
  }

  /// Quotes run from a few words to several verses. Step the size down so the
  /// long ones still fit without the short ones looking lost.
  static double _quoteSizeFor(String quote) {
    final length = quote.length;
    if (length < 90) return 68;
    if (length < 180) return 58;
    if (length < 300) return 48;
    if (length < 460) return 40;
    return 34;
  }
}
