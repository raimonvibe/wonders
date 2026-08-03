import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/data/wonders_repository.dart';
import 'package:bible_wonders/features/speech/speech_controller.dart';
import 'package:bible_wonders/providers.dart';
import 'package:bible_wonders/router.dart';
import 'package:bible_wonders/theme/app_theme.dart';
import 'package:bible_wonders/theme/metrics.dart';
import 'package:bible_wonders/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two things that change when the window is not a phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the reading measure', () {
    // 66 characters at an average advance of 0.52 em: the middle of the
    // 50–75 range the typographic and accessibility guidance both name.
    test('a phone keeps the gutter it always had', () {
      expect(readingGutter(400, fontSize: 18), 20);
      expect(readingGutter(360, fontSize: 18), 20);
    });

    test('a tablet gets margins instead of a longer line', () {
      final gutter = readingGutter(1000, fontSize: 18);
      expect(gutter, greaterThan(20));

      // What is left over is the column, and it has to land inside the range.
      final column = 1000 - gutter * 2;
      final characters = column / (18 * 0.52);
      expect(characters, inInclusiveRange(50, 75));
    });

    test('a larger reading size widens the column rather than lengthening it',
        () {
      final small = 1000 - readingGutter(1000, fontSize: 18) * 2;
      final large = 1000 - readingGutter(1000, fontSize: 27) * 2;
      expect(large, greaterThan(small));
    });

    test('never narrower than the caller asked for', () {
      expect(readingGutter(300, fontSize: 18, minimum: 12), 12);
    });
  });

  group('the navigation', () {
    late WondersRepository repo;

    setUpAll(() async {
      repo = await WondersRepository.load();
    });

    Future<void> pumpApp(WidgetTester tester, {required double width}) async {
      tester.view
        ..physicalSize = Size(width, 900)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await Prefs.load();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsProvider.overrideWithValue(prefs),
            wondersProvider.overrideWithValue(repo),
            speechProvider.overrideWith((ref) => SpeechController(prefs)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.of(Palette.pine),
            routerConfig: AppRouter.build(),
          ),
        ),
      );
      await tester.pump();
    }

    // Material's compact/medium boundary is 600. Below it a rail is explicitly
    // the wrong component; at it and above, a bottom bar is a row of controls
    // along the far edge of a screen held by its sides.
    testWidgets('a phone gets the bottom bar', (tester) async {
      await pumpApp(tester, width: 400);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('just under the breakpoint is still a phone', (tester) async {
      await pumpApp(tester, width: 599);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('a tablet gets the rail', (tester) async {
      await pumpApp(tester, width: 800);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the destinations are the same four either way', (tester) async {
      await pumpApp(tester, width: 800);
      for (final label in ['Wonders', 'Bible', 'Tour', 'More']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });
  });
}
