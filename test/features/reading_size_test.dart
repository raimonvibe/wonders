import 'package:bible_wonders/app.dart';
import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/data/wonders_repository.dart';
import 'package:bible_wonders/features/speech/speech_controller.dart';
import 'package:bible_wonders/providers.dart';
import 'package:bible_wonders/theme/metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The reading size, and the screens it is supposed to reach.
///
/// It used to reach one: `passage_view` multiplied its own font sizes by it and
/// no other screen did, so 160% gave a reader large scripture in the Bible tab
/// and a wonder card — including the verse quoted at the top of it — still at
/// 100%, one tap away. The fix is a TextScaler in the MediaQuery at the root
/// rather than a number each screen has to remember to use, and what is worth
/// testing is that it arrives everywhere and that nothing breaks when it does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the scaler itself', () {
    test('composes with the platform rather than replacing it', () {
      const platform = TextScaler.linear(1.3);
      const scaler = ReadingScaler(platform, 1.6);

      // Both settings are real requests and the reader means both.
      expect(scaler.scale(18), closeTo(18 * 1.6 * 1.3, 0.001));
    });

    test('a reader who has changed nothing gets the size as written', () {
      const scaler = ReadingScaler(TextScaler.noScaling, 1);
      expect(scaler.scale(18), 18);
    });

    test('two of the same value compare equal, two different do not', () {
      // MediaQuery decides whether to rebuild by comparing these, so a scaler
      // that always compared equal would leave the slider doing nothing.
      const a = ReadingScaler(TextScaler.noScaling, 1.6);
      const b = ReadingScaler(TextScaler.noScaling, 1.6);
      const c = ReadingScaler(TextScaler.noScaling, 0.85);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('the size reaches every screen', () {
    late WondersRepository repo;

    setUpAll(() async {
      repo = await WondersRepository.load();
    });

    Future<void> pumpApp(
      WidgetTester tester, {
      required double reading,
      double platform = 1.0,
      double width = 400,
    }) async {
      tester.view
        ..physicalSize = Size(width, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({'reader-font-scale': reading});
      final prefs = await Prefs.load();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            wondersProvider.overrideWithValue(repo),
            speechProvider.overrideWith((ref) => SpeechController(prefs)),
          ],
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(platform)),
            child: const BibleWondersApp(),
          ),
        ),
      );
      await tester.pump();
    }

    /// What the app would actually paint a verse at, read from the tree the
    /// reader is looking at rather than from the provider.
    double effective(WidgetTester tester) {
      final context = tester.element(find.byType(Scaffold).first);
      return MediaQuery.textScalerOf(context).scale(18);
    }

    testWidgets('the wonders tab honours it, not just the reader',
        (tester) async {
      await pumpApp(tester, reading: 1);
      final atOne = effective(tester);

      await pumpApp(tester, reading: 1.6);
      expect(effective(tester), closeTo(atOne * 1.6, 0.001));
    });

    testWidgets('and it stacks on top of the device\'s own setting',
        (tester) async {
      await pumpApp(tester, reading: 1.6, platform: 1.3);
      expect(effective(tester), closeTo(18 * 1.6 * 1.3, 0.001));
    });

    testWidgets('a reader who has changed nothing sees no change',
        (tester) async {
      await pumpApp(tester, reading: 1);
      expect(effective(tester), 18);
    });

    // The reason to be careful about making this global. Before, the catalog
    // only ever saw the platform's scale; now the slider multiplies it, and the
    // worst case a reader can actually reach is both at once.
    for (final width in [400.0, 1400.0]) {
      testWidgets('nothing overflows at 1.6 on top of 1.6, at ${width}pt wide',
          (tester) async {
        await pumpApp(tester, reading: 1.6, platform: 1.6, width: width);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
