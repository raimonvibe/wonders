import 'package:bible_wonders/features/speech/speech_voices.dart';
import 'package:flutter_test/flutter_test.dart';

/// The picker's contents.
///
/// The list a device hands back is not one anyone would choose a scripture
/// voice from, and the ways it is wrong are quiet ones — a joke voice sitting
/// third from the top reads as a bug in the app, not as an Apple default.
void main() {
  const zarvox = SpeechVoice(name: 'Zarvox', locale: 'en-US');
  const grandma = SpeechVoice(name: 'Grandma (Deutsch (Deutschland))', locale: 'de-DE');
  const eloquence = SpeechVoice(name: 'Eloquence Reed', locale: 'en-GB');
  const samantha = SpeechVoice(name: 'Samantha', locale: 'en-US');
  const enhanced = SpeechVoice(name: 'Daniel (Enhanced)', locale: 'en-GB');
  const dutch = SpeechVoice(name: 'Xander', locale: 'nl-NL');

  group('novelty voices', () {
    test('are recognised however the platform dresses the name', () {
      expect(isNoveltyVoice(zarvox), isTrue);
      expect(isNoveltyVoice(grandma), isTrue, reason: 'the locale suffix hides it');
      expect(isNoveltyVoice(eloquence), isTrue);
      expect(isNoveltyVoice(samantha), isFalse);
    });

    test('are dropped from the usable list', () {
      final usable = usableVoices([zarvox, samantha, grandma, dutch]);
      expect(usable.map((v) => v.name), isNot(contains('Zarvox')));
      expect(usable.map((v) => v.name), contains('Samantha'));
    });

    test('are kept when they are all a device has', () {
      // An empty picker is worse than a silly one.
      expect(usableVoices([zarvox, grandma]), hasLength(2));
    });
  });

  group('ordering', () {
    test('puts a higher-quality English voice first', () {
      final sorted = usableVoices([dutch, samantha, enhanced]);
      expect(sorted.first.name, 'Daniel (Enhanced)');
    });

    test('groups by language with English leading', () {
      final groups = groupVoicesByLanguage(usableVoices([dutch, samantha]));
      expect(groups.first.label, startsWith('English'));
      expect(groups.last.label, startsWith('Dutch'));
    });
  });

  group('the saved voice', () {
    test('is restored when it is still installed', () {
      final chosen = pickDefaultVoice([dutch, samantha], preferredId: dutch.id);
      expect(chosen, dutch);
    });

    test('gives way to an English voice once it is uninstalled', () {
      final chosen = pickDefaultVoice(
        [samantha, dutch],
        preferredId: 'Ghost|en-US',
      );
      expect(chosen, samantha);
    });

    test('is null only when the device offers nothing', () {
      expect(pickDefaultVoice(const []), isNull);
    });
  });

  test('ids survive a name with spaces in it', () {
    // "Microsoft David Desktop" is a real voice name; splitting an id on the
    // space would have made it unmatchable after a restart.
    const spaced = SpeechVoice(name: 'Microsoft David Desktop', locale: 'en-US');
    expect(pickDefaultVoice([spaced], preferredId: spaced.id), spaced);
  });

  test('language labels degrade to the tag rather than lying', () {
    const invented = SpeechVoice(name: 'Test', locale: 'qq-ZZ');
    expect(invented.languageLabel, 'qq-ZZ');
    expect(samantha.languageLabel, 'English (United States)');
  });
}
