import 'package:bible_wonders/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// The race that put "Wonders and" in the app bar with "Hope" below it.
///
/// `GoogleFonts` reads the bundled files out of the asset bundle
/// asynchronously, so text laid out before they land is laid out in the system
/// fallback. The face arriving is *not* a rebuild — the framework notifies
/// `PaintingBinding.systemFonts`, every `RenderParagraph` marks itself dirty and
/// lays out again, and no widget's `build` runs. So a widget that measured text
/// and kept the number — which is what `AppBarTitle.toolbarHeightFor`,
/// `gridTileExtent`, `readingGutter`, `_columnsThatFit` and
/// `ShareCard._quoteSizeFor` all do — keeps a number taken in the wrong face.
///
/// This file must run before anything else loads the typefaces, which is why it
/// is its own file: `flutter test` gives each file its own isolate, and
/// `GoogleFonts` caches for the life of one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The app bar's own face and size, measuring the app's own name.
  double widthOfTheTitle() {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Wonders and Hope',
        style: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  test('the same string measures differently before the faces land', () async {
    bundleTheTypefaces();

    // Playfair has been *asked for* by the call above and has not arrived, so
    // this is the fallback face. If this ever comes out equal to the second
    // measurement the race has gone away on its own and the await below is no
    // longer load-bearing — which would be worth knowing.
    final fallback = widthOfTheTitle();

    await theTypefacesHaveLoaded();
    final playfair = widthOfTheTitle();

    expect(
      playfair,
      isNot(closeTo(fallback, 0.5)),
      reason: 'the fallback and the real face measure the same, so this test '
          'is no longer demonstrating anything',
    );

    // And once waited for, they stay put: a second wait resolves against an
    // empty queue, so nothing is still in flight to change a measurement after
    // the first frame.
    await GoogleFonts.pendingFonts();
    expect(widthOfTheTitle(), playfair);
  });
}
