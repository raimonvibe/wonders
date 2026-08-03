import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/features/speech/speech_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Losing the race with the speech service must not cost the reader a voice.
///
/// main() starts initialise() before the first frame, which on Android is the
/// moment the engine is least likely to have finished binding. getVoices does
/// not fail then — it answers null — so nothing throws, and a picker that gave
/// up on the first ask would leave the reading on the engine's default with the
/// reader's own choice ignored.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Voices as the platform spells them: maps of name and locale.
  const samantha = {'name': 'Samantha', 'locale': 'en-US'};
  const daniel = {'name': 'Daniel', 'locale': 'en-GB'};
  const voices = [samantha, daniel];

  late int getVoicesCalls;

  /// [answer] is handed the call number, one-based, and decides what the engine
  /// says that time — which is how "silent until the service binds" is spelt.
  void mockEngine(Object? Function(int call) answer) {
    getVoicesCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getVoices':
          getVoicesCalls++;
          return answer(getVoicesCalls);
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

  Object? never(int _) => null;
  Object? always(int _) => voices;

  Future<Prefs> freshPrefs([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return Prefs(await SharedPreferences.getInstance());
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('a service that binds late', () {
    test('is asked again until it answers, inside one initialise', () async {
      // Silent for the first two asks, bound by the third — the ordinary case
      // on a cold start, and the one the reader must never notice.
      mockEngine((call) => call >= 3 ? voices : null);
      final speech = SpeechController(await freshPrefs());

      await speech.initialise();

      expect(getVoicesCalls, 3);
      expect(
        speech.state.voices.map((v) => v.name),
        unorderedEquals(['Samantha', 'Daniel']),
      );
      expect(
        speech.state.voiceId,
        isNotNull,
        reason: 'the first reading must already be in a chosen voice',
      );
    });

    test('is given up on eventually, leaving speech usable', () async {
      mockEngine(never);
      final speech = SpeechController(await freshPrefs());

      await speech.initialise();

      expect(
        getVoicesCalls,
        greaterThan(1),
        reason: 'one ask is not a fair question',
      );
      expect(speech.state.voices, isEmpty);
      expect(
        speech.state.ready,
        isTrue,
        reason: 'speech still works on the engine default',
      );
    });
  });

  group('an initialise that came back empty', () {
    test('does not settle, so a later caller tries again', () async {
      mockEngine(never);
      final speech = SpeechController(await freshPrefs());

      await speech.initialise();
      final afterFirst = getVoicesCalls;
      await speech.initialise();

      expect(getVoicesCalls, greaterThan(afterFirst));
    });

    test('leaves the saved voice alone for that retry', () async {
      mockEngine(never);
      final speech = SpeechController(
        await freshPrefs({'flutter.speech-voice': 'Daniel|en-GB'}),
      );

      await speech.initialise();

      expect(
        speech.state.voiceId,
        'Daniel|en-GB',
        reason: 'the failed pass must not overwrite it with a default',
      );
    });
  });

  test('a load that worked is not repeated', () async {
    mockEngine(always);
    final speech = SpeechController(await freshPrefs());

    await speech.initialise();
    await speech.initialise();
    await speech.initialise();

    expect(getVoicesCalls, 1);
  });

  /// A voice substituted for an absent one must not become the preference.
  ///
  /// Android's `-network` voices are in getVoices only while the engine can
  /// reach its server, so the saved voice goes missing and comes back on its
  /// own. Substituting is right; remembering the substitute is not — that is
  /// how a reader ends up permanently in an accent they never chose.
  group('a voice that is only temporarily missing', () {
    const auNetwork = {'name': 'en-au-x-aua-network', 'locale': 'en-AU'};
    const inNetwork = {'name': 'en-in-x-ena-network', 'locale': 'en-IN'};
    const savedId = 'en-au-x-aua-network|en-AU';

    test('is stood in for, without the stand-in being saved', () async {
      final prefs = await freshPrefs({'flutter.speech-voice': savedId});
      mockEngine((_) => [inNetwork]);
      final speech = SpeechController(prefs);

      await speech.initialise();

      expect(speech.state.voiceId, 'en-in-x-ena-network|en-IN');
      expect(
        prefs.speechVoiceId,
        savedId,
        reason: 'the reader chose en-AU and has not unchosen it',
      );
    });

    test('is read again the moment the device offers it', () async {
      final prefs = await freshPrefs({'flutter.speech-voice': savedId});

      mockEngine((_) => [inNetwork]);
      final stale = SpeechController(prefs);
      await stale.initialise();
      expect(stale.state.voiceId, 'en-in-x-ena-network|en-IN');

      // The next launch, with the network voice reachable again.
      mockEngine((_) => [auNetwork, inNetwork]);
      final fresh = SpeechController(prefs);
      await fresh.initialise();

      expect(fresh.state.voiceId, savedId);
    });
  });
}
