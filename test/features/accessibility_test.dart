import 'dart:math' as math;

import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/data/reading_paths.dart';
import 'package:bible_wonders/data/wonders_repository.dart';
import 'package:bible_wonders/features/speech/speech_controller.dart';
import 'package:bible_wonders/features/tour/tour_screen.dart';
import 'package:bible_wonders/features/wonders/wonders_home_screen.dart';
import 'package:bible_wonders/providers.dart';
import 'package:bible_wonders/theme/app_theme.dart';
import 'package:bible_wonders/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The screens, against Flutter's own accessibility guidelines.
///
/// `flutter_test` ships four matchers that walk the semantics tree and check
/// what a person auditing by hand would check: that everything you can tap is
/// big enough to hit, that everything you can tap says what it is, and that
/// text stands off its background far enough to read. They are worth more than
/// hand-written expectations because they check the whole tree rather than the
/// parts somebody remembered to assert on.
///
/// Both of this app's palettes get a run: pine and ocean are different greens
/// and blues over different grounds, and a contrast ratio that clears 4.5:1 in
/// one is not thereby cleared in the other.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WondersRepository repo;

  setUpAll(() async {
    repo = await WondersRepository.load();
  });

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget screen, {
    required Palette palette,
    ReadingPath path = ReadingPath.catalog,
    Size size = const Size(400, 800),
  }) async {
    tester.view
      ..physicalSize = size
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
    container.read(pathProvider.notifier).setPath(path);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.of(palette), home: screen),
      ),
    );
    await tester.pump();
    return container;
  }

  /// Size and labelling, which the matchers measure exactly.
  ///
  /// `textContrastGuideline` is deliberately not here, and the reason is worth
  /// writing down. It samples the rendered pixels and takes the commonest light
  /// and dark tones it finds inside a label's rectangle — so for small text in
  /// a light-weight face it reads the antialiased edges rather than the ink. It
  /// failed the selected path chip at 1.93:1 the moment the real Inter was
  /// bundled, where the colours actually in play, #0E2A20 on #F4A261, are
  /// 7.4:1. The check below computes the ratio from the two colours instead,
  /// which is the thing the guideline is a proxy for and does not care how a
  /// glyph is rasterised.
  Future<void> audit(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  }

  for (final entry in {'pine': Palette.pine, 'ocean': Palette.ocean}.entries) {
    testWidgets('the catalog is accessible in ${entry.key}', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const WondersHomeScreen(), palette: entry.value);
      await audit(tester);
      handle.dispose();
    });

    testWidgets('the theme picker is accessible in ${entry.key}',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const WondersHomeScreen(),
        palette: entry.value,
        path: ReadingPath.theme,
      );
      await audit(tester);
      handle.dispose();
    });

    testWidgets('the tour is accessible in ${entry.key}', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const TourScreen(), palette: entry.value);
      await audit(tester);
      handle.dispose();
    });

    group('${entry.key} has readable contrast', () {
      final palette = entry.value;
      final scheme = AppTheme.of(palette).colorScheme;

      /// Every pairing the app actually paints, with what it is painted on.
      ///
      /// Stated as pairs rather than sampled off the screen so that changing a
      /// shade in the palette fails here, at the place the decision was made,
      /// rather than on whichever screen happened to be under test.
      final pairs = <String, (Color, Color)>{
        'body copy on the page': (palette.shade100, palette.shade900),
        'secondary copy on the page': (palette.shade200, palette.shade900),
        'section labels on the page': (palette.shade300, palette.shade900),
        'section labels on a panel': (palette.shade300, palette.shade800),
        'verse numbers on the page': (palette.shade400, palette.shade900),
        'a quote reference': (Palette.accent, palette.shade900),
        'text on a surface': (scheme.onSurface, scheme.surface),
        'a filled button': (scheme.onPrimary, scheme.primary),
        // The one the pixel-sampling matcher got wrong.
        'the selected path chip': (
          scheme.onSecondaryContainer,
          scheme.secondaryContainer,
        ),
      };

      pairs.forEach((what, colours) {
        test(what, () {
          final (ink, ground) = colours;
          expect(
            _contrastRatio(ink, ground),
            greaterThanOrEqualTo(4.5),
            reason: '$what is ${_contrastRatio(ink, ground).toStringAsFixed(2)}'
                ':1, and WCAG AA asks 4.5 for text this size',
          );
        });
      });
    });
  }
}

/// WCAG 2.1's contrast ratio: (L1 + 0.05) / (L2 + 0.05).
double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}
