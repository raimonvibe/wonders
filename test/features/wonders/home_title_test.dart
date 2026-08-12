import 'dart:math' as math;

import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/data/reading_paths.dart';
import 'package:bible_wonders/data/wonders_repository.dart';
import 'package:bible_wonders/features/speech/speech_controller.dart';
import 'package:bible_wonders/features/wonders/wonders_home_screen.dart';
import 'package:bible_wonders/providers.dart';
import 'package:bible_wonders/theme/app_bar_title.dart';
import 'package:bible_wonders/theme/app_theme.dart';
import 'package:bible_wonders/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's own name, on the screen it opens on, at every shape a phone comes
/// in.
///
/// [AppBarTitle] has its own unit tests against a bar built to order. This one
/// pumps the real screen, because every version of this bug so far has been a
/// disagreement between what the title measured and what the bar around it
/// actually gave it — and a bar built to order in a test agrees with itself.
///
/// The widths go down to 240 on purpose. A phone is 360 or 412 points wide
/// until the reader opens Android's *Display size* and turns it up, which is the
/// setting sitting directly beside the font size that this app's whole
/// accessibility story is built around. Turned up, a 412 pt phone reports about
/// 300, and "Wonders and Hope" stops fitting on one line.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WondersRepository repo;

  setUpAll(() async {
    // The measurement is of a typeface, so it must not depend on whether this
    // machine has fetched one.
    GoogleFonts.config.allowRuntimeFetching = false;
    repo = await WondersRepository.load();
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    required double textScale,
    required double width,
  }) async {
    tester.view
      ..physicalSize = Size(width, 780)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        wondersProvider.overrideWithValue(repo),
        // Never spoken to — the Listen button only watches its state — but the
        // app bar will not build without it.
        speechProvider.overrideWith((ref) => SpeechController(prefs)),
      ],
    );
    addTearDown(container.dispose);
    container.read(pathProvider.notifier).setPath(ReadingPath.catalog);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.of(Palette.ocean),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 780),
              textScaler: TextScaler.linear(textScale),
              // A real phone has a status bar and the test surface does not.
              // AppBar pads itself by it, so leaving it out would measure a bar
              // no reader ever sees.
              padding: const EdgeInsets.only(top: 32),
            ),
            child: const WondersHomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  const title = 'Wonders and Hope';
  const statusBar = 32.0;

  /// 3.0 is past anything a phone offers and is here because the answer must
  /// stop changing above the ceiling the framework imposes, not because anyone
  /// will read at it.
  for (final width in [240.0, 280.0, 300.0, 320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.3, 1.34, 1.6, 2.08, 3.0]) {
      testWidgets('${width.toInt()} pt at ${scale}x', (tester) async {
        await pumpHome(tester, textScale: scale, width: width);

        final bar = tester.getRect(find.byType(AppBar));
        final block = tester.getRect(find.byType(AppBarTitle));

        // Nothing lost. The app's name is the one string on this screen that
        // cannot be abbreviated away.
        expect(
          tester.renderObject<RenderParagraph>(find.text(title))
              .didExceedMaxLines,
          isFalse,
          reason: 'the title was truncated',
        );

        // Nothing clipped: every rule the title paints lives inside its own box,
        // so a box inside the bar is gold inside the bar.
        expect(block.top, greaterThanOrEqualTo(bar.top - 0.5));
        expect(block.bottom, lessThanOrEqualTo(bar.bottom + 0.5));

        // And nothing wasted. A bar taller than the title plus its padding is
        // room reserved for lines that were never painted — which is what a
        // safety margin in the width estimate used to buy, at 125 points of
        // chrome around 46 points of title.
        expect(
          bar.height - statusBar,
          lessThanOrEqualTo(math.max(kToolbarHeight, block.height + 16) + 1),
          reason: 'the bar reserved more than the title used',
        );
      });
    }
  }
}
