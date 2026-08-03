import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/data/reading_paths.dart';
import 'package:bible_wonders/data/wonders_repository.dart';
import 'package:bible_wonders/features/speech/speech_controller.dart';
import 'package:bible_wonders/features/wonders/wonders_home_screen.dart';
import 'package:bible_wonders/providers.dart';
import 'package:bible_wonders/theme/app_theme.dart';
import 'package:bible_wonders/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The home screen has to survive a small phone and a large text size at once.
///
/// That combination is not a corner case here: raising the system font is the
/// first thing a reader who is struggling to read does, and this app is for
/// reading. A `RenderFlex` overflow is a caught exception in a test and a
/// yellow-and-black stripe across the catalog on a phone, so pumping the screen
/// *is* the assertion — `takeException` only makes it explicit about which one.
///
/// 320 × 640 is the narrowest phone still in the wild; 1.6 is the top of
/// Android's font-size slider before Accessibility's own scaling.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WondersRepository repo;

  setUpAll(() async {
    repo = await WondersRepository.load();
  });

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    required double textScale,
    required ReadingPath path,
    Size size = const Size(320, 640),
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
        // Never spoken to — the Listen button only watches its state — but the
        // app bar will not build without it.
        speechProvider.overrideWith((ref) => SpeechController(prefs)),
      ],
    );
    addTearDown(container.dispose);

    container.read(pathProvider.notifier).setPath(path);
    container.read(lastWonderProvider.notifier).set(repo.startHere().first.id);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.of(Palette.pine),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const WondersHomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  /// Walk the screen from top to bottom.
  ///
  /// The slivers below the fold are built lazily, so a screen that is only
  /// pumped has never laid out its toolbar and would pass this test by not
  /// having drawn the thing being tested.
  Future<void> scrollThrough(WidgetTester tester, {int screens = 4}) async {
    for (var i = 0; i < screens; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
    }
  }

  for (final scale in [1.0, 1.3, 1.6]) {
    testWidgets('the catalog lays out at ${scale}x text', (tester) async {
      await pumpHome(tester, textScale: scale, path: ReadingPath.catalog);

      // The sort control is the widest thing on the toolbar and the reason the
      // count beside it had to stop sharing a Row with it.
      await tester.scrollUntilVisible(
        find.text('Bible order'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Best known'), findsOneWidget);

      await scrollThrough(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the theme picker lays out at ${scale}x text', (tester) async {
      await pumpHome(tester, textScale: scale, path: ReadingPath.theme);
      await scrollThrough(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the era picker lays out at ${scale}x text', (tester) async {
      await pumpHome(tester, textScale: scale, path: ReadingPath.era);
      await scrollThrough(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an empty result lays out inside a sliver', (tester) async {
    // The shared EmptyState is hosted in an Expanded on the library screen and
    // in a sliver here, which arrive with bounded and unbounded height
    // respectively. This is the unbounded one — the case a scroll view inside
    // it would throw on.
    final container =
        await pumpHome(tester, textScale: 1.6, path: ReadingPath.startHere);
    container.read(pathProvider.notifier).setQuery('zzzznotawonder');
    await tester.pump();
    await scrollThrough(tester, screens: 2);

    expect(find.text('Clear search'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row names the other accounts rather than hinting at them',
      (tester) async {
    // The Gospel parallels are the reason the branching-arrow icon existed.
    // Search for one by name so its row is the only thing on the list.
    final withParallels = repo.wonders.firstWhere(
      (w) => repo.parallelsOf(w).isNotEmpty,
    );
    final expected = repo
        .parallelsOf(withParallels)
        .map((w) => w.passage.bookName)
        .join(', ');

    final container =
        await pumpHome(tester, textScale: 1.0, path: ReadingPath.catalog);
    container.read(pathProvider.notifier).setQuery(withParallels.title);
    await tester.pump();
    await scrollThrough(tester, screens: 2);

    expect(find.textContaining('also in $expected'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
