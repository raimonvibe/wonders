/// The voice list, cleaned up and ordered.
///
/// Ported from the voice half of ../../lib/readAloud.ts, and it exists for the
/// same reason: the list the platform hands back is not a list anyone would
/// want to choose a scripture voice from. It is unsorted, it mixes every
/// installed language together, and on Apple devices it contains a couple of
/// dozen joke voices.
library;

/// One voice, as flutter_tts describes it.
///
/// `getVoices` returns maps of `{name, locale}` on Android and adds `quality`,
/// `gender` and `identifier` on iOS. Only the first two are common to both, and
/// they are also the two `setVoice` wants back, so they are all this keeps.
class SpeechVoice {
  const SpeechVoice({required this.name, required this.locale});

  /// Builds a voice from one entry of flutter_tts's `getVoices`, or null if the
  /// entry is missing either field — some Android engines return partial rows.
  static SpeechVoice? fromPlatform(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name']?.toString();
    final locale = raw['locale']?.toString();
    if (name == null || locale == null || name.isEmpty || locale.isEmpty) {
      return null;
    }
    return SpeechVoice(name: name, locale: locale);
  }

  final String name;
  final String locale;

  /// What gets persisted and compared. The platform has no stable voice id
  /// common to both operating systems, and the name alone is not unique across
  /// locales. The bar is the separator because voice names contain spaces
  /// ("Microsoft David Desktop") but never that.
  String get id => '$name|$locale';

  /// What `setVoice` takes.
  Map<String, String> get selector => {'name': name, 'locale': locale};

  /// What the picker shows.
  ///
  /// [name] is whatever the platform calls the voice, and the platforms do not
  /// agree on what that means. iOS and Windows give it a human one — "Samantha",
  /// "Microsoft David Desktop" — and those are shown as they are. Android's
  /// Google engine gives an identifier: `en-au-x-aua-network`. Putting that in
  /// front of a reader choosing a voice for scripture is asking them to pick by
  /// part number.
  ///
  /// The picker already groups by language, so the language is not repeated
  /// here. What is left that a reader can actually act on is whether the voice
  /// needs a connection — a network voice sounds better and goes quiet on a
  /// train — with the engine's own three-letter code kept as the tiebreaker
  /// between two voices that are otherwise described identically.
  String get displayName {
    // `en-IN-language` is Google's stand-in for "whichever voice this device
    // considers default here". It is a real, selectable entry and it sits at
    // the top of its group, so it is the one a reader is most likely to try —
    // which makes leaving it reading `en-IN-language` the worst of the lot.
    if (_googleDefaultVoiceId.hasMatch(name)) return 'Device default';

    final match = _googleVoiceId.firstMatch(name);
    if (match == null) return name;

    final code = match.group(1)!.toUpperCase();
    final needsNetwork = match.group(2)!.toLowerCase() == 'network';
    return needsNetwork ? 'Online · $code' : 'Offline · $code';
  }

  /// [displayName] with the language in front, for the closed picker.
  ///
  /// Inside the open list the language is the group heading, so repeating it on
  /// every row would be noise. Closed, there is no heading — and "Offline · AUA"
  /// on its own tells a reader nothing about what they are about to hear.
  String get pickerLabel => '$languageLabel · $displayName';

  /// `en-au-x-aua-network`, `cmn-cn-x-ccc-local`: a language tag, `x`, a short
  /// voice code, and how it is synthesised.
  static final _googleVoiceId = RegExp(
    r'^[a-z]{2,3}-[a-z]{2,3}-x-([a-z0-9]+)-(local|network)$',
    caseSensitive: false,
  );

  /// `en-IN-language` — this locale's default voice, whichever that turns out
  /// to be.
  static final _googleDefaultVoiceId = RegExp(
    r'^[a-z]{2,3}-[a-z]{2,3}-language$',
    caseSensitive: false,
  );

  /// "en-GB" — the locale as a language tag, however the platform spelt it.
  String get languageTag => locale.replaceAll('_', '-');

  /// The bare language subtag, "en".
  String get language => languageTag.split('-').first.toLowerCase();

  bool get isEnglish => language == 'en';

  /// "English (United Kingdom)", falling back to the raw tag. Dart has no
  /// equivalent of Intl.DisplayNames without pulling in a package, so this
  /// covers the languages a phone is likely to have installed and degrades to
  /// the tag for the rest.
  String get languageLabel {
    final parts = languageTag.split('-');
    final name = _languageNames[parts.first.toLowerCase()];
    if (name == null) return languageTag;
    if (parts.length < 2) return name;
    final region = _regionNames[parts[1].toUpperCase()];
    return region == null
        ? '$name (${parts[1].toUpperCase()})'
        : '$name ($region)';
  }

  @override
  bool operator ==(Object other) => other is SpeechVoice && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A language, with the voices installed for it.
class VoiceGroup {
  const VoiceGroup({required this.label, required this.voices});
  final String label;
  final List<SpeechVoice> voices;
}

/// Joke and character voices the operating system ships alongside real ones.
///
/// Carried over from the website, including the reason: Apple's novelty set all
/// report as en-US, so filtering by language does not remove them — they have
/// to be named. The second block is the Eloquence-era character set, which
/// exists in many languages and is equally wrong for scripture.
const _noveltyVoiceNames = <String>{
  'albert',
  'bad news',
  'bahh',
  'bells',
  'boing',
  'bubbles',
  'cellos',
  'deranged',
  'fred',
  'good news',
  'hysterical',
  'jester',
  'organ',
  'pipe organ',
  'superstar',
  'trinoids',
  'whisper',
  'wobble',
  'zarvox',
  // character voices
  'eddy',
  'flo',
  'grandma',
  'grandpa',
  'reed',
  'rocko',
  'sandy',
  'shelley',
};

/// "Grandma (Deutsch (Deutschland))" becomes "grandma".
String _baseVoiceName(String name) =>
    name.split('(').first.split(' - ').first.trim().toLowerCase();

bool isNoveltyVoice(SpeechVoice voice) {
  if (RegExp('eloquence', caseSensitive: false).hasMatch(voice.name)) {
    return true;
  }
  return _noveltyVoiceNames.contains(_baseVoiceName(voice.name));
}

int _qualityScore(SpeechVoice voice) {
  var score = 0;
  // Android names its higher-quality downloads with these words; iOS uses
  // "premium" and "enhanced" for the same idea.
  if (RegExp('natural|premium|enhanced|neural', caseSensitive: false)
      .hasMatch(voice.name)) {
    score += 5;
  }
  if (RegExp('google|microsoft|apple|siri', caseSensitive: false)
      .hasMatch(voice.name)) {
    score += 2;
  }
  if (voice.isEnglish) score += 3;

  // Android's `-network` voices are synthesised on a server. They sound better
  // than their `-local` twin, and they are the reason the default used to
  // wander: a network voice is only in getVoices when the engine can reach the
  // server, so the best-ranked English voice was a different one from one
  // launch to the next — en-au one time, en-in the next — and a reader who had
  // chosen nothing heard the passage in a new accent for no reason they could
  // see. Ranked just below the local voice of the same quality, so the default
  // is something the device always has, and a network voice is still there in
  // the picker for anyone who wants it.
  if (RegExp('network', caseSensitive: false).hasMatch(voice.name)) score -= 1;

  return score;
}

List<SpeechVoice> sortVoices(List<SpeechVoice> voices) {
  final sorted = [...voices];
  sorted.sort((a, b) {
    final diff = _qualityScore(b) - _qualityScore(a);
    if (diff != 0) return diff;
    return a.name.compareTo(b.name);
  });
  return sorted;
}

/// Every genuine voice on the device, best first.
///
/// Falls back to the raw list if a device somehow offers nothing else, so the
/// reader never ends up with an empty picker.
List<SpeechVoice> usableVoices(List<SpeechVoice> voices) {
  final genuine = voices.where((v) => !isNoveltyVoice(v)).toList();
  return sortVoices(genuine.isNotEmpty ? genuine : voices);
}

/// The saved voice if it is still installed, otherwise the best English one.
///
/// The text is English, so start on an English voice even though every language
/// is on offer — [sortVoices] has already put the best of them first.
SpeechVoice? pickDefaultVoice(List<SpeechVoice> voices, {String? preferredId}) {
  if (voices.isEmpty) return null;
  if (preferredId != null) {
    for (final voice in voices) {
      if (voice.id == preferredId) return voice;
    }
  }
  final english = voices.where((v) => v.isEnglish).toList();
  return english.isNotEmpty ? english.first : voices.first;
}

/// Voices grouped by spoken language, for the picker. English leads because
/// the text is English; the rest are alphabetical.
List<VoiceGroup> groupVoicesByLanguage(List<SpeechVoice> voices) {
  final byTag = <String, List<SpeechVoice>>{};
  for (final voice in voices) {
    byTag.putIfAbsent(voice.languageTag, () => []).add(voice);
  }

  final groups = byTag.entries
      .map(
        (entry) => (
          tag: entry.key,
          label: entry.value.first.languageLabel,
          voices: sortVoices(entry.value),
        ),
      )
      .toList();

  groups.sort((a, b) {
    final aEnglish = a.tag.toLowerCase().startsWith('en');
    final bEnglish = b.tag.toLowerCase().startsWith('en');
    if (aEnglish != bEnglish) return aEnglish ? -1 : 1;
    return a.label.compareTo(b.label);
  });

  return groups
      .map((g) => VoiceGroup(label: g.label, voices: g.voices))
      .toList();
}

const _languageNames = <String, String>{
  'af': 'Afrikaans',
  'ar': 'Arabic',
  'bg': 'Bulgarian',
  'bn': 'Bengali',
  'ca': 'Catalan',
  'cs': 'Czech',
  'da': 'Danish',
  'de': 'German',
  'el': 'Greek',
  'en': 'English',
  'es': 'Spanish',
  'et': 'Estonian',
  'fa': 'Persian',
  'fi': 'Finnish',
  'fr': 'French',
  'he': 'Hebrew',
  'hi': 'Hindi',
  'hr': 'Croatian',
  'hu': 'Hungarian',
  'id': 'Indonesian',
  'it': 'Italian',
  'ja': 'Japanese',
  'ko': 'Korean',
  'lt': 'Lithuanian',
  'lv': 'Latvian',
  'ms': 'Malay',
  'nb': 'Norwegian',
  'nl': 'Dutch',
  'no': 'Norwegian',
  'pl': 'Polish',
  'pt': 'Portuguese',
  'ro': 'Romanian',
  'ru': 'Russian',
  'sk': 'Slovak',
  'sl': 'Slovenian',
  'sr': 'Serbian',
  'sv': 'Swedish',
  'sw': 'Swahili',
  'ta': 'Tamil',
  'te': 'Telugu',
  'th': 'Thai',
  'tr': 'Turkish',
  'uk': 'Ukrainian',
  'ur': 'Urdu',
  'vi': 'Vietnamese',
  'zh': 'Chinese',
};

const _regionNames = <String, String>{
  'AU': 'Australia',
  'BE': 'Belgium',
  'BR': 'Brazil',
  'CA': 'Canada',
  'CH': 'Switzerland',
  'CN': 'China',
  'DE': 'Germany',
  'ES': 'Spain',
  'FR': 'France',
  'GB': 'United Kingdom',
  'HK': 'Hong Kong',
  'IE': 'Ireland',
  'IN': 'India',
  'IT': 'Italy',
  'JP': 'Japan',
  'KR': 'South Korea',
  'MX': 'Mexico',
  // Google ships English voices for these too, and an unlisted region shows as
  // a bare code — "English (NG)" in the picker, which is the sort of thing that
  // makes an app look unfinished. The English-speaking ones are worth naming;
  // the fallback still covers everything else.
  'NG': 'Nigeria',
  'KE': 'Kenya',
  'GH': 'Ghana',
  'PH': 'Philippines',
  'PK': 'Pakistan',
  'SG': 'Singapore',
  'NL': 'Netherlands',
  'NZ': 'New Zealand',
  'PT': 'Portugal',
  'RU': 'Russia',
  'SE': 'Sweden',
  'TW': 'Taiwan',
  'US': 'United States',
  'ZA': 'South Africa',
};
