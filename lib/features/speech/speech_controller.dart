import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/prefs.dart';
import 'speech_chunk.dart';
import 'speech_voices.dart';

/// Where read-aloud is up to.
enum SpeechStatus { idle, playing, paused }

/// What "read this wonder aloud" should cover.
///
/// The website's Tour / Passage / Both switcher, ported with its ids intact so
/// the two codebases store the same value — see [Prefs]. The default is [card]
/// for the reason the website gives: turning speech on should never surprise
/// you with a chapter of scripture you did not ask for.
enum SpeechReach {
  card('tour', 'The card'),
  passage('passage', 'The passage'),
  both('both', 'Both');

  const SpeechReach(this.id, this.label);
  final String id;
  final String label;

  static SpeechReach parse(String? id) =>
      values.firstWhere((r) => r.id == id, orElse: () => SpeechReach.card);
}

/// How long until the reading stops on its own.
///
/// Durations only. "Stop at the end of the chapter" is not offered because it
/// is not a setting — a queue ends when it ends, and the reading stops there
/// already.
enum SleepAfter {
  off('Off', null),
  five('5 min', Duration(minutes: 5)),
  fifteen('15 min', Duration(minutes: 15)),
  thirty('30 min', Duration(minutes: 30)),
  sixty('60 min', Duration(minutes: 60));

  const SleepAfter(this.label, this.duration);
  final String label;
  final Duration? duration;
}

/// Everything the UI needs to know about speech, in one immutable value.
class SpeechState {
  const SpeechState({
    required this.status,
    required this.voices,
    required this.voiceId,
    required this.rate,
    required this.pitch,
    required this.reach,
    required this.autoNarrateTour,
    this.source,
    this.index = 0,
    this.ready = false,
    this.error,
    this.sleepAfter = SleepAfter.off,
  });

  final SpeechStatus status;
  final Speakable? source;
  final int index;

  final List<SpeechVoice> voices;
  final String? voiceId;

  /// A multiplier on the platform's normal speaking rate, not a raw engine
  /// value. 1.0 is normal on both operating systems — see
  /// [SpeechController._applyRate], which is where the two are reconciled.
  final double rate;
  final double pitch;

  final SpeechReach reach;
  final bool autoNarrateTour;

  /// False until the engine has answered, which on Android means the service
  /// has bound. The controls stay visible meanwhile; they simply do nothing.
  final bool ready;

  /// Set when the engine refused to speak, so a screen can say so once.
  final String? error;

  final SleepAfter sleepAfter;

  bool get isIdle => status == SpeechStatus.idle;
  bool get isPlaying => status == SpeechStatus.playing;
  bool get isPaused => status == SpeechStatus.paused;
  bool get isSleeping => sleepAfter != SleepAfter.off;

  SpeechChunk? get chunk {
    final chunks = source?.chunks;
    if (chunks == null || index < 0 || index >= chunks.length) return null;
    return chunks[index];
  }

  /// What is being spoken right now, for views that mark the active line.
  /// Null while idle, so a highlight never outlives the speech.
  String? get anchor => isIdle ? null : chunk?.anchor;

  String? get label => chunk?.label ?? source?.title;

  double get progress {
    final total = source?.length ?? 0;
    return total == 0 ? 0 : (index + 1) / total;
  }

  /// Whether [id] is the material currently loaded — what a Listen button uses
  /// to decide between "start me" and "pause what is already mine".
  bool isSource(String id) => source?.id == id;

  SpeechVoice? get voice {
    for (final v in voices) {
      if (v.id == voiceId) return v;
    }
    return null;
  }

  SpeechState copyWith({
    SpeechStatus? status,
    Speakable? source,
    bool clearSource = false,
    int? index,
    List<SpeechVoice>? voices,
    String? voiceId,
    double? rate,
    double? pitch,
    SpeechReach? reach,
    bool? autoNarrateTour,
    bool? ready,
    String? error,
    bool clearError = false,
    SleepAfter? sleepAfter,
  }) {
    return SpeechState(
      status: status ?? this.status,
      source: clearSource ? null : (source ?? this.source),
      index: index ?? this.index,
      voices: voices ?? this.voices,
      voiceId: voiceId ?? this.voiceId,
      rate: rate ?? this.rate,
      pitch: pitch ?? this.pitch,
      reach: reach ?? this.reach,
      autoNarrateTour: autoNarrateTour ?? this.autoNarrateTour,
      ready: ready ?? this.ready,
      error: clearError ? null : (error ?? this.error),
      sleepAfter: sleepAfter ?? this.sleepAfter,
    );
  }
}

/// The one voice in the app.
///
/// Every screen speaks through this controller rather than owning a
/// [FlutterTts] of its own, for the same reason there is only one PassageView:
/// two engines mean two things talking at once, and no way for the mini player
/// to stop whichever one you meant. SpeechAudioHandler wraps this same object
/// for the lock screen, so the notification and the app can never disagree.
///
/// The queue is driven by the completion handler rather than by awaiting each
/// utterance, which is what makes pause, skip and stop take effect immediately
/// instead of after the current chunk. Stale callbacks are filtered by
/// generation — the engine delivers completions for utterances that were
/// cancelled, and without the guard a stop starts the next chunk.
class SpeechController extends StateNotifier<SpeechState> {
  SpeechController(this._prefs)
      : super(
          SpeechState(
            status: SpeechStatus.idle,
            voices: const [],
            voiceId: _prefs.speechVoiceId,
            rate: _prefs.speechRate,
            pitch: _prefs.speechPitch,
            reach: SpeechReach.parse(_prefs.speechReach),
            autoNarrateTour: _prefs.autoNarrateTour,
          ),
        );

  final Prefs _prefs;
  final FlutterTts _tts = FlutterTts();

  /// Answered by MainActivity. Android only, and only for the Android 13
  /// notification permission — see [_ensureNotificationPermission].
  static const _platform = MethodChannel('wonders/notifications');

  /// Bumped by anything that abandons the queue. An utterance records the
  /// generation it was started under; a callback whose generation no longer
  /// matches is from a chunk nobody is listening to any more.
  int _generation = 0;
  int _utteranceGeneration = -1;

  /// Consecutive engine errors. A queue where every chunk fails would otherwise
  /// walk to the end of a chapter in silence.
  int _errors = 0;
  static const _maxConsecutiveErrors = 3;

  /// The platform's own rate scale, as the engine reports it. Both operating
  /// systems put normal at 0.5 — iOS because that is
  /// AVSpeechUtteranceDefaultSpeechRate, Android because flutter_tts doubles
  /// whatever it is given so the two agree. Read rather than assumed, because
  /// this is exactly the kind of constant that changes in a point release.
  double _rateMin = 0.0;
  double _rateNormal = 0.5;
  double _rateMax = 1.0;

  Timer? _sleepTimer;

  /// Set when the sleep timer has fired. The reading is not cut off mid
  /// sentence — it finishes the line it is on and stops there.
  bool _sleepPending = false;

  bool _disposed = false;
  bool _askedForNotifications = false;
  Future<void>? _initialising;

  /// Bind the engine and ask it what it can do.
  ///
  /// Called from main() after AudioService.init, so the audio session
  /// audio_service installs is in place before the iOS category below adjusts
  /// it. Idempotent, so a test or a second entry point can call it safely.
  ///
  /// Memoised, but only once it has something to show for itself: a run that
  /// came back without a voice list is forgotten, so the next caller tries
  /// again. See the end of [_init].
  Future<void> initialise() => _initialising ??= _init();

  Future<void> _init() async {
    _tts.setCompletionHandler(_onComplete);
    _tts.setErrorHandler(_onError);
    // Cancel and pause are both things this controller asks for and has already
    // recorded, so the handlers exist only to stop flutter_tts logging that
    // nothing is listening.
    _tts.setCancelHandler(() {});
    _tts.setPauseHandler(() {});
    _tts.setContinueHandler(() {});

    // iOS silences the `ambient` category with the ring switch, which for a
    // read-aloud feature reads as "the app is broken". `playback` is the
    // category for audio that is the point of the screen, and spokenAudio is
    // what makes other spoken-word apps yield rather than talk over us. It is
    // also what audio_service needs to keep speaking once the app is not on
    // screen.
    if (!kIsWeb && Platform.isIOS) {
      try {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions
                .interruptSpokenAudioAndMixWithOthers,
          ],
          IosTextToSpeechAudioMode.spokenAudio,
        );
      } catch (_) {
        // An audio session this old device will not grant is not a reason to
        // have no speech at all.
      }
    }

    try {
      final range = await _tts.getSpeechRateValidRange;
      _rateMin = range.min;
      _rateNormal = range.normal;
      _rateMax = range.max;
    } catch (_) {
      // Keep the defaults above.
    }

    final voices = await _loadVoices();
    if (_disposed) return;

    // An empty list is not necessarily the truth.
    //
    // Android binds the speech service asynchronously, and main() calls this
    // before the first frame — the moment it is least likely to have finished.
    // Lose that race and getVoices answers null rather than failing, so the
    // memoised future would hold an empty picker for the life of the session:
    // no voice to apply, and the reader stuck on whatever locale the engine
    // defaults to, with their saved choice ignored. Dropping the future lets
    // the next Listen ask again, by which time the service has bound.
    //
    // A platform that genuinely has no getVoices — desktop, some Android
    // engines — simply answers empty a second time. The cost is one call per
    // press, which is the right way round: a retry that is never needed is
    // cheaper than a picker that is empty for good.
    if (voices.isEmpty) _initialising = null;

    // copyWith keeps the existing voiceId when [chosen] is null, so a failed
    // load leaves the reader's saved preference in place for that retry.
    final chosen = pickDefaultVoice(voices, preferredId: state.voiceId);
    state = state.copyWith(voices: voices, voiceId: chosen?.id, ready: true);
    await _applySettings();
  }

  /// Ask for the notification permission the lock-screen controls need.
  ///
  /// Asked here rather than at launch, because a permission prompt on first
  /// open has no context: nothing has happened yet that a notification would be
  /// about. The first time somebody presses Listen, it does.
  ///
  /// Asked once per session, and a refusal is not an error. Speech works
  /// either way — what is lost is only the controls outside the app, so this
  /// must never stand between the reader and the reading.
  Future<void> _ensureNotificationPermission() async {
    if (kIsWeb || !Platform.isAndroid || _askedForNotifications) return;
    _askedForNotifications = true;
    try {
      await _platform.invokeMethod<bool>('ensureNotificationPermission');
    } catch (_) {
      // No channel on this build, or the activity has gone. Neither is worth
      // silencing the app over.
    }
  }

  Future<List<SpeechVoice>> _loadVoices() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return const [];
      final parsed =
          raw.map(SpeechVoice.fromPlatform).whereType<SpeechVoice>().toList();
      return usableVoices(parsed);
    } catch (_) {
      // Desktop and some Android engines do not implement getVoices. Speech
      // still works on the system default; the picker is simply empty.
      return const [];
    }
  }

  /* --- playback ----------------------------------------------------------- */

  /// Replace whatever is being said with [source].
  ///
  /// [from] is the chunk to begin at, which is how a wonder's passage starts on
  /// the verse the card cites instead of at verse 1.
  Future<void> start(Speakable source, {int from = 0}) async {
    if (source.isEmpty) return;
    await initialise();
    await _ensureNotificationPermission();

    _generation++;
    _errors = 0;
    await _safely(_tts.stop);
    await _applySettings();

    if (_disposed) return;
    state = state.copyWith(
      source: source,
      index: from.clamp(0, source.length - 1),
      status: SpeechStatus.playing,
      clearError: true,
    );
    await _speakCurrent();
  }

  /// Play, pause or resume [source] — the whole behaviour of a Listen button.
  ///
  /// Tapping Listen on material that is already playing pauses it; tapping it
  /// on anything else takes over. Restarting a *finished* source starts it
  /// again from [from] rather than doing nothing.
  Future<void> toggle(Speakable source, {int from = 0}) async {
    if (state.isSource(source.id)) {
      if (state.isPlaying) return pause();
      if (state.isPaused) return resume();
    }
    return start(source, from: from);
  }

  /// What the lock screen's play button means, and the mini player's.
  ///
  /// Three cases in one: resume a pause, replay a queue that ran to the end, or
  /// do nothing when there is nothing loaded.
  Future<void> play() async {
    if (state.isPaused) return resume();
    final source = state.source;
    if (source != null && state.isIdle) return start(source);
  }

  Future<void> pause() async {
    if (!state.isPlaying) return;
    // No generation bump: the utterance is suspended, not abandoned, and
    // resume() speaks the same text to continue it.
    state = state.copyWith(status: SpeechStatus.paused);
    await _safely(_tts.pause);
  }

  /// Continue the paused chunk.
  ///
  /// Speaking the identical string is how both platforms resume: iOS calls
  /// `continueSpeaking`, and Android picks the utterance back up from the word
  /// it stopped on. Handing over a different string would restart it.
  Future<void> resume() async {
    if (!state.isPaused) return;
    state = state.copyWith(status: SpeechStatus.playing);
    await _speakCurrent();
  }

  Future<void> stop() async {
    _generation++;
    _errors = 0;
    _cancelSleepTimer();
    state = state.copyWith(
      status: SpeechStatus.idle,
      index: 0,
      clearSource: true,
      sleepAfter: SleepAfter.off,
    );
    await _safely(_tts.stop);
  }

  /// Move [delta] chunks and speak from there. Skipping past either end stops.
  Future<void> skip(int delta) async {
    final source = state.source;
    if (source == null) return;

    final next = state.index + delta;
    if (next < 0 || next >= source.length) return stop();

    _generation++;
    _errors = 0;
    await _safely(_tts.stop);
    if (_disposed) return;

    state = state.copyWith(index: next, status: SpeechStatus.playing);
    await _speakCurrent();
  }

  /// Jump straight to a chunk, for a view that lets you tap a verse to hear it.
  Future<void> seekToAnchor(String anchor) async {
    final source = state.source;
    if (source == null) return;
    final index = source.indexOfAnchor(anchor);
    if (index < 0 || index == state.index) return;
    await skip(index - state.index);
  }

  Future<void> _speakCurrent() async {
    final chunk = state.chunk;
    if (chunk == null) return stop();

    _utteranceGeneration = _generation;
    final spoken = await _safely(() => _tts.speak(chunk.text));
    if (!spoken && !_disposed) {
      state = state.copyWith(
        status: SpeechStatus.idle,
        clearSource: true,
        error: 'This device has no speech engine available.',
      );
    }
  }

  void _onComplete() {
    if (_disposed) return;
    if (_utteranceGeneration != _generation) return;
    if (!state.isPlaying) return;
    _errors = 0;

    // The sleep timer fired while this line was being read. Letting it finish
    // and stopping here is the difference between drifting off and being cut
    // off mid sentence.
    if (_sleepPending) {
      _sleepPending = false;
      unawaited(stop());
      return;
    }

    final source = state.source;
    if (source == null) return;

    final next = state.index + 1;
    if (next >= source.length) {
      // Reaching the end is not the same as being stopped: leave the source in
      // place so the mini player can offer it again, but go quiet.
      _cancelSleepTimer();
      state = state.copyWith(
        status: SpeechStatus.idle,
        index: 0,
        sleepAfter: SleepAfter.off,
      );
      return;
    }

    state = state.copyWith(index: next);
    unawaited(_speakCurrent());
  }

  void _onError(dynamic message) {
    if (_disposed) return;
    if (_utteranceGeneration != _generation) return;
    if (!state.isPlaying) return;

    _errors++;
    if (_errors >= _maxConsecutiveErrors) {
      state = state.copyWith(
        status: SpeechStatus.idle,
        clearSource: true,
        error: 'Speech stopped: $message',
      );
      return;
    }

    // One bad chunk should not end the chapter — step over it, the way the
    // website's reader does.
    final source = state.source;
    if (source == null) return;
    final next = state.index + 1;
    if (next >= source.length) {
      state = state.copyWith(status: SpeechStatus.idle, index: 0);
      return;
    }
    state = state.copyWith(index: next);
    unawaited(_speakCurrent());
  }

  /* --- the sleep timer ---------------------------------------------------- */

  void setSleepAfter(SleepAfter value) {
    _cancelSleepTimer();
    state = state.copyWith(sleepAfter: value);

    final duration = value.duration;
    if (duration == null) return;

    _sleepTimer = Timer(duration, () {
      if (_disposed) return;
      // Stop now if nothing is being said; otherwise let the current line
      // finish and stop in _onComplete.
      if (state.isPlaying) {
        _sleepPending = true;
      } else {
        unawaited(stop());
      }
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepPending = false;
  }

  /* --- settings ----------------------------------------------------------- */

  /// Changes take effect on the next chunk rather than mid-sentence, which is
  /// why the settings sheet has a Preview button.
  Future<void> setRate(double rate) async {
    state = state.copyWith(rate: rate);
    _save(_prefs.setSpeechRate(rate));
    await _applyRate();
  }

  Future<void> setPitch(double pitch) async {
    state = state.copyWith(pitch: pitch);
    _save(_prefs.setSpeechPitch(pitch));
    await _safely(() => _tts.setPitch(pitch));
  }

  Future<void> setVoice(SpeechVoice voice) async {
    state = state.copyWith(voiceId: voice.id);
    _save(_prefs.setSpeechVoiceId(voice.id));
    await _applyVoice();
  }

  void setReach(SpeechReach reach) {
    state = state.copyWith(reach: reach);
    _save(_prefs.setSpeechReach(reach.id));
  }

  void setAutoNarrateTour(bool value) {
    state = state.copyWith(autoNarrateTour: value);
    _save(_prefs.setAutoNarrateTour(value));
  }

  /// Say one short line in the current voice, so the picker can be judged by
  /// ear. Deliberately not part of the queue: it interrupts nothing and leaves
  /// no source behind.
  Future<void> preview(String text) async {
    if (state.isPlaying || state.isPaused) return;
    await initialise();
    _generation++;
    await _safely(_tts.stop);
    await _applySettings();
    _utteranceGeneration = -1; // completion must not advance a queue
    await _safely(() => _tts.speak(text));
  }

  Future<void> _applySettings() async {
    await _applyVoice();
    await _applyRate();
    await _safely(() => _tts.setPitch(state.pitch));
    await _safely(() => _tts.setVolume(1.0));
  }

  Future<void> _applyVoice() async {
    final voice = state.voice;
    if (voice == null) return;
    // Language first: on Android an engine that has not been switched to the
    // voice's locale mispronounces it, and setVoice alone does not move it.
    await _safely(() => _tts.setLanguage(voice.languageTag));
    await _safely(() => _tts.setVoice(voice.selector));
  }

  /// Turn the user-facing multiplier into whatever this platform calls normal.
  Future<void> _applyRate() async {
    final value = (_rateNormal * state.rate).clamp(_rateMin, _rateMax);
    await _safely(() => _tts.setSpeechRate(value));
  }

  /// Every engine call, wrapped. flutter_tts throws a MissingPluginException on
  /// platforms with no implementation and a PlatformException when an engine is
  /// mid-restart, and neither is worth taking the app down for. Returns whether
  /// the call got through.
  Future<bool> _safely(Future<dynamic> Function() call) async {
    try {
      await call();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _save(Future<void> future) {
    future.catchError((Object _) {});
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancelSleepTimer();
    _tts.stop().catchError((Object _) => null);
    super.dispose();
  }
}
