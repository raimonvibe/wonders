import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/features/speech/speech_chunk.dart';
import 'package:bible_wonders/features/speech/speech_controller.dart';
import 'package:bible_wonders/features/speech/speech_settings_sheet.dart';
import 'package:bible_wonders/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Trying a voice must not cost the reader their place.
///
/// The sheet used to grey this out during a reading and say "Stop the reading
/// to try a voice", which asked for the one thing that is expensive: stop()
/// clears the source and the index with it. Pausing keeps both, so the mini
/// player still has the chapter and a play button on it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> spoken;

  void mockEngine() {
    spoken = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getVoices':
          return [
            {'name': 'Samantha', 'locale': 'en-US'},
          ];
        case 'getSpeechRateValidRange':
          return {
            'min': 0.0,
            'normal': 0.5,
            'max': 1.0,
            'platform': 'android',
          };
        case 'speak':
          spoken.add('${(call.arguments as Object?) ?? ''}');
          return 1;
        default:
          return 1;
      }
    });
  }

  Future<Prefs> freshPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return Prefs(await SharedPreferences.getInstance());
  }

  final chapter = Speakable(
    id: 'GEN.1',
    title: 'Genesis 1',
    chunks: const [
      SpeechChunk('In the beginning'),
      SpeechChunk('And the earth was formless'),
      SpeechChunk('And God said'),
    ],
  );

  setUp(mockEngine);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<SpeechController> reading() async {
    final speech = SpeechController(await freshPrefs());
    await speech.initialise();
    await speech.start(chapter, from: 1);
    expect(speech.state.isPlaying, isTrue);
    return speech;
  }

  test('previewing during a reading pauses it rather than stopping it',
      () async {
    final speech = await reading();

    await speech.preview('Hear this voice');

    expect(speech.state.isPaused, isTrue, reason: 'paused, not idle');
    expect(speech.state.source?.id, 'GEN.1', reason: 'the chapter is kept');
    expect(speech.state.index, 1, reason: 'and so is the place in it');
  });

  test('the preview is what actually gets spoken', () async {
    final speech = await reading();
    spoken.clear();

    await speech.preview('Hear this voice');

    expect(spoken, contains('Hear this voice'));
  });

  test('several voices can be tried one after another', () async {
    final speech = await reading();

    await speech.preview('one');
    await speech.preview('two');
    await speech.preview('three');

    // Still paused on the same line, three previews later.
    expect(speech.state.isPaused, isTrue);
    expect(speech.state.index, 1);
    expect(spoken.where((s) => s == 'three'), isNotEmpty);
  });

  test('and the reading picks up again afterwards', () async {
    final speech = await reading();
    await speech.preview('Hear this voice');
    spoken.clear();

    await speech.resume();

    expect(speech.state.isPlaying, isTrue);
    expect(speech.state.index, 1);
    // The current line from its start: the engine's own pause context did not
    // survive the preview, so this repeats a line rather than losing one.
    expect(spoken, contains('And the earth was formless'));
  });

  test('with nothing playing it is simply a preview', () async {
    final speech = SpeechController(await freshPrefs());
    await speech.initialise();

    await speech.preview('Hear this voice');

    expect(speech.state.isIdle, isTrue);
    expect(speech.state.source, isNull);
    expect(spoken, contains('Hear this voice'));
  });

  group('the control on the sheet', () {
    Future<void> pumpSheet(WidgetTester tester, SpeechController speech) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [speechProvider.overrideWith((ref) => speech)],
          child: const MaterialApp(
            home:
                Scaffold(body: SingleChildScrollView(child: SpeechSettings())),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('is offered during a reading rather than withheld',
        (tester) async {
      final speech = await reading();
      await pumpSheet(tester, speech);

      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Pause the reading and hear this voice'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNotNull, reason: 'never disabled');
    });

    testWidgets('and says what it will do before it does it', (tester) async {
      final speech = await reading();
      await pumpSheet(tester, speech);
      expect(
        find.text('Pause the reading and hear this voice'),
        findsOneWidget,
      );
      expect(find.text('Stop the reading to try a voice'), findsNothing);
    });

    testWidgets('with nothing playing it just offers the voice',
        (tester) async {
      final speech = SpeechController(await freshPrefs());
      await speech.initialise();
      await pumpSheet(tester, speech);

      expect(find.text('Hear this voice'), findsOneWidget);
    });
  });
}
