import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/features/speech/speech_bar.dart';
import 'package:bible_wonders/features/speech/speech_chunk.dart';
import 'package:bible_wonders/features/speech/speech_controller.dart';
import 'package:bible_wonders/providers.dart';
import 'package:bible_wonders/theme/app_theme.dart';
import 'package:bible_wonders/theme/metrics.dart';
import 'package:bible_wonders/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The read-aloud controls are drawn bigger than Material's 24, because they
/// are pressed by someone listening rather than looking. What has to stay true
/// is that they are bigger *inside the same box*: the mini player puts five of
/// them in a row with a title, and the narrowest phone this app supports has
/// 320 pt to give them.
class _FixedSpeech extends SpeechController {
  _FixedSpeech(super.prefs, SpeechState fixed) {
    state = fixed;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final source = Speakable(
    id: 'test',
    // Long enough to want every point of room the buttons leave it.
    title: 'The children of Israel went into the middle of the sea',
    chunks: const [
      SpeechChunk('one', anchor: 'a'),
      SpeechChunk('two', anchor: 'b'),
      SpeechChunk('three', anchor: 'c'),
    ],
  );

  Future<void> pumpBar(
    WidgetTester tester, {
    double width = 320,
    double textScale = 1.0,
  }) async {
    tester.view
      ..physicalSize = Size(width, 640)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    final fixed = SpeechState(
      status: SpeechStatus.playing,
      voices: const [],
      voiceId: null,
      rate: 1,
      pitch: 1,
      reach: SpeechReach.values.first,
      autoNarrateTour: false,
      source: source,
      index: 1,
      ready: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          speechProvider.overrideWith((ref) => _FixedSpeech(prefs, fixed)),
        ],
        child: MaterialApp(
          theme: AppTheme.of(Palette.pine),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const Scaffold(bottomNavigationBar: SpeechBar()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the icons are drawn bigger than Material draws them',
      (tester) async {
    await pumpBar(tester);
    // Measured rather than read off the widget: IconButton passes its iconSize
    // down through an IconTheme, so Icon.size is null and the number that
    // matters is the one it actually laid out at.
    final icons = find.byType(Icon);
    expect(icons, findsWidgets);
    for (final element in icons.evaluate()) {
      final box = tester.getSize(find.byWidget(element.widget));
      expect(box.width, speechIconSize);
      expect(box.width, greaterThan(24), reason: 'bigger than Material draws');
    }
  });

  testWidgets('and the buttons are the size they always were', (tester) async {
    await pumpBar(tester);
    // 28 of icon inside 6 of padding either side is the 40 that
    // VisualDensity.compact asked for, which is what the row was laid out
    // around. A bigger glyph must not cost the title its width.
    for (final button in find.byType(IconButton).evaluate()) {
      final box = tester.getSize(find.byWidget(button.widget));
      expect(box.height, 40);
      expect(box.width, 40);
    }
  });

  // "Fits their box on all devices" is decided here: five buttons and a title
  // on the narrowest screen the app supports, at the largest text a reader can
  // ask for on top of the largest the system offers.
  for (final width in [320.0, 400.0, 1400.0]) {
    for (final scale in [1.0, 1.6, 2.56]) {
      testWidgets('nothing overflows at ${width}pt and ${scale}x text',
          (tester) async {
        await pumpBar(tester, width: width, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the title keeps room to say something on a narrow phone',
      (tester) async {
    await pumpBar(tester);
    final title = tester.getSize(find.text(source.title));
    expect(title.width, greaterThan(80));
  });
}
