import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/features/speech/speech_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Losing the race with the speech service must not cost the picker.
///
/// main() calls initialise() before the first frame, which on Android is the
/// moment the engine is least likely to have finished binding. getVoices does
/// not fail then — it answers null — so nothing throws and a memoised init
/// would hold an empty picker for the life of the session.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Voices as the platform spells them: maps of name and locale.
  const voices = [
    {'name': 'Samantha', 'locale': 'en-US'},
    {'name': 'Daniel', 'locale': 'en-GB'},
  ];

  late int getVoicesCalls;

  /// Answers [replies] in order, repeating the last one once they run out —
  /// so "null, then a list" describes a service that binds between two calls.
  void mockEngine(List<Object?> replies) {
    getVoicesCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getVoices':
          final index = getVoicesCalls.clamp(0, replies.length - 1);
          getVoicesCalls++;
          return replies[index];
        case 'getSpeechRateValidRange':
          return {
            'min': 0.0,
            'normal': 0.5,
            'max': 1.0,
            'platform': 'android',
          };
        default:
          // setLanguage, setVoice, setPitch, setVolume, setSpeechRate: the
          // engine's own "did it" reply.
          return 1;
      }
    });
  }

  Future<SpeechController> controller() async {
    SharedPreferences.setMockInitialValues({});
    return SpeechController(Prefs(await SharedPreferences.getInstance()));
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('an unbound engine leaves the picker empty but does not settle',
      () async {
    mockEngine([null]);
    final speech = await controller();

    await speech.initialise();

    expect(speech.state.voices, isEmpty);
    expect(
      speech.state.ready,
      isTrue,
      reason: 'speech still works on the engine default',
    );
  });

  test('the next caller asks again, and gets the voices', () async {
    mockEngine([null, voices]);
    final speech = await controller();

    await speech.initialise();
    expect(speech.state.voices, isEmpty);

    await speech.initialise();

    expect(getVoicesCalls, 2);
    // Order is sortVoices' business, and it has its own tests.
    expect(
      speech.state.voices.map((v) => v.name),
      unorderedEquals(['Samantha', 'Daniel']),
    );
    expect(speech.state.voiceId, isNotNull);
  });

  test('a load that worked is not repeated', () async {
    mockEngine([voices]);
    final speech = await controller();

    await speech.initialise();
    await speech.initialise();
    await speech.initialise();

    expect(getVoicesCalls, 1);
  });

  test('a retry keeps the reader\'s saved voice', () async {
    SharedPreferences.setMockInitialValues({'speech-voice': 'Daniel|en-GB'});
    mockEngine([null, voices]);
    final speech =
        SpeechController(Prefs(await SharedPreferences.getInstance()));

    await speech.initialise();
    await speech.initialise();

    expect(
      speech.state.voiceId,
      'Daniel|en-GB',
      reason: 'the failed pass must not overwrite it with a default',
    );
  });
}
