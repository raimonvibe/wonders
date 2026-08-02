import 'package:shared_preferences/shared_preferences.dart';

import 'reading_paths.dart';

/// The small amount of state that survives a restart.
///
/// The keys are the same strings the website writes to localStorage. They
/// don't sync — there is no account — but keeping them identical means the two
/// codebases describe "where the reader is" the same way, and a future sync
/// has nothing to reconcile.
class Prefs {
  Prefs(this._prefs);

  static const _pathKey = 'wonders-path';
  static const _sortKey = 'wonders-sort';
  static const _seenOverviewKey = 'wonders-seen-overview';
  static const _lastWonderKey = 'wonders-last-read';
  static const _tourStepKey = 'wonders-tour-step';

  /// Read aloud. Rate and reach carry the website's key and value spellings —
  /// see useTourNarration.ts — because they mean the same thing on both. The
  /// voice does not: a browser identifies a voice by URI and a phone by name
  /// and locale, so that one is app-only rather than a value the website would
  /// misread.
  static const _speechRateKey = 'tour-speech-rate';
  static const _speechReachKey = 'tour-speech-mode';
  static const _autoNarrateTourKey = 'tour-speech-on';

  /// App-only, no website counterpart.
  static const _lastChapterKey = 'bible-last-chapter';
  static const _themeLockKey = 'theme-lock';
  static const _fontScaleKey = 'reader-font-scale';
  static const _speechVoiceKey = 'speech-voice';
  static const _speechPitchKey = 'speech-pitch';

  final SharedPreferences _prefs;

  static Future<Prefs> load() async =>
      Prefs(await SharedPreferences.getInstance());

  ReadingPath get path => ReadingPath.parse(_prefs.getString(_pathKey));
  Future<void> setPath(ReadingPath value) =>
      _prefs.setString(_pathKey, value.id);

  SortMode get sort => SortMode.parse(_prefs.getString(_sortKey));
  Future<void> setSort(SortMode value) => _prefs.setString(_sortKey, value.id);

  /// First launch shows the overview; afterwards it goes straight to browsing.
  bool get hasSeenOverview => _prefs.getBool(_seenOverviewKey) ?? false;
  Future<void> markOverviewSeen() => _prefs.setBool(_seenOverviewKey, true);

  /// Drives "continue where you left off" on the Wonders home.
  String? get lastWonderId => _prefs.getString(_lastWonderKey);
  Future<void> setLastWonderId(String id) =>
      _prefs.setString(_lastWonderKey, id);

  int get tourStep => _prefs.getInt(_tourStepKey) ?? 0;
  Future<void> setTourStep(int step) => _prefs.setInt(_tourStepKey, step);

  String? get lastChapterId => _prefs.getString(_lastChapterKey);
  Future<void> setLastChapterId(String id) =>
      _prefs.setString(_lastChapterKey, id);

  /// Null means "follow the testament being read"; a value pins one palette.
  /// See ThemeController.
  String? get themeLock => _prefs.getString(_themeLockKey);
  Future<void> setThemeLock(String? testamentId) async {
    if (testamentId == null) {
      await _prefs.remove(_themeLockKey);
    } else {
      await _prefs.setString(_themeLockKey, testamentId);
    }
  }

  double get fontScale => _prefs.getDouble(_fontScaleKey) ?? 1.0;
  Future<void> setFontScale(double value) =>
      _prefs.setDouble(_fontScaleKey, value);

  /* --- read aloud --------------------------------------------------------- */

  /// A multiple of the device's normal speaking rate, not an engine value.
  /// SpeechController is where the two are reconciled.
  double get speechRate {
    final saved = _prefs.getDouble(_speechRateKey) ?? 1.0;
    return saved.clamp(0.5, 2.0);
  }

  Future<void> setSpeechRate(double value) =>
      _prefs.setDouble(_speechRateKey, value);

  double get speechPitch {
    final saved = _prefs.getDouble(_speechPitchKey) ?? 1.0;
    return saved.clamp(0.5, 2.0);
  }

  Future<void> setSpeechPitch(double value) =>
      _prefs.setDouble(_speechPitchKey, value);

  /// `name|locale`, as SpeechVoice.id spells it. Null until one is chosen, and
  /// ignored if that voice is later uninstalled.
  String? get speechVoiceId => _prefs.getString(_speechVoiceKey);
  Future<void> setSpeechVoiceId(String value) =>
      _prefs.setString(_speechVoiceKey, value);

  /// 'tour', 'passage' or 'both' — see SpeechReach.
  String? get speechReach => _prefs.getString(_speechReachKey);
  Future<void> setSpeechReach(String value) =>
      _prefs.setString(_speechReachKey, value);

  /// Whether moving to a tour step reads it out without being asked. Off by
  /// default, as it is on the website.
  bool get autoNarrateTour => _prefs.getBool(_autoNarrateTourKey) ?? false;
  Future<void> setAutoNarrateTour(bool value) =>
      _prefs.setBool(_autoNarrateTourKey, value);
}
