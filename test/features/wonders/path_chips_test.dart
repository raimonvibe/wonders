import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/data/reading_paths.dart';
import 'package:bible_wonders/data/wonders_repository.dart';
import 'package:bible_wonders/features/speech/speech_controller.dart';
import 'package:bible_wonders/features/wonders/wonders_home_screen.dart';
import 'package:bible_wonders/providers.dart';
import 'package:bible_wonders/theme/app_theme.dart';
import 'package:bible_wonders/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The four ways in, whole, at every shape a phone comes in.
///
/// These chips are how the reader chooses what to read, and nothing else on the
/// screen says where one goes — the sentence below them describes only the path
/// already selected. So a cut label is not a shorter label, it is a different
/// one: "By book o" reads as something somebody wrote.
///
/// The widths go down to 240 for the reason given in home_title_test.dart —
/// Android's *Display size* sits beside the font size, and turned up it reports
/// a 412 pt phone as about 300.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WondersRepository repo;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    repo = await WondersRepository.load();
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    required double textScale,
    required double width,
  }) async {
    tester.view
      ..physicalSize = Size(width, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        wondersProvider.overrideWithValue(repo),
        speechProvider.overrideWith((ref) => SpeechController(prefs)),
      ],
    );
    addTearDown(container.dispose);
    container.read(pathProvider.notifier).setPath(ReadingPath.catalog);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.of(Palette.pine),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: TextScaler.linear(textScale),
              padding: const EdgeInsets.only(top: 32),
            ),
            child: const WondersHomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final width in [240.0, 280.0, 320.0, 360.0, 412.0, 800.0]) {
    // 1.6 is the top of the reading slider; 2.08 is that on a phone whose own
    // font is already at 1.3. Chips are not app bar titles, so nothing clamps
    // them — they get the reader's size in full.
    for (final scale in [1.0, 1.3, 1.6, 2.08]) {
      testWidgets('${width.toInt()} pt at ${scale}x', (tester) async {
        await pumpHome(tester, textScale: scale, width: width);

        for (final path in ReadingPath.values) {
          final label = find.text(path.label);
          expect(label, findsOneWidget, reason: '${path.label} is missing');

          // The chip clips by default, so a label that does not fit simply
          // loses its last letters with nothing to say it did. This is the
          // assertion that the arrangement found room for all four.
          expect(
            tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
            isFalse,
            reason: '"${path.label}" was truncated',
          );
        }

        expect(tester.takeException(), isNull);
      });
    }
  }
}
