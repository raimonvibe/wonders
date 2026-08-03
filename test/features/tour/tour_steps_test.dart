import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/data/wonders_repository.dart';
import 'package:bible_wonders/features/speech/speech_controller.dart';
import 'package:bible_wonders/features/tour/tour_screen.dart';
import 'package:bible_wonders/providers.dart';
import 'package:bible_wonders/theme/app_theme.dart';
import 'package:bible_wonders/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The tour used to be swipeable and nothing else.
///
/// A four-pixel progress bar was the only thing that said how far in you were,
/// and a card that scrolls vertically gives no hint that it also moves
/// sideways — so a reader could open the tour, read one wonder, and never learn
/// there were thirteen more. These cover the bar that says so.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WondersRepository repo;

  setUpAll(() async {
    repo = await WondersRepository.load();
  });

  Future<void> pumpTour(WidgetTester tester, {double textScale = 1.0}) async {
    tester.view
      ..physicalSize = const Size(320, 640)
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
        child: MaterialApp(
          theme: AppTheme.of(Palette.pine),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const TourScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('says which step this is, of how many', (tester) async {
    await pumpTour(tester);
    expect(find.text('Step 1 of 14'), findsOneWidget);
  });

  testWidgets('there is no way back from the first step', (tester) async {
    await pumpTour(tester);

    final back = tester.widget<TextButton>(
      find.ancestor(of: find.text('Back'), matching: find.byType(TextButton)),
    );
    expect(back.onPressed, isNull);
  });

  testWidgets('Next moves on, and the count follows', (tester) async {
    await pumpTour(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 14'), findsOneWidget);

    // And back again, so the pair is symmetrical rather than one-way.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 14'), findsOneWidget);
  });

  testWidgets('the bar survives a raised text size', (tester) async {
    await pumpTour(tester, textScale: 1.6);
    expect(tester.takeException(), isNull);
  });
}
