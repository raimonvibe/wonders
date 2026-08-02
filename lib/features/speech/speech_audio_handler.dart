import 'package:audio_service/audio_service.dart';

import 'speech_controller.dart';

/// Puts read-aloud on the lock screen, and keeps it alive when the app is not.
///
/// A thin adapter, deliberately. All the behaviour lives in [SpeechController];
/// this class only translates between the system's vocabulary of play, pause
/// and skip and the controller's, and publishes what the controller is doing so
/// the notification, the lock screen, headset buttons and Android Auto all see
/// the same thing.
///
/// Nothing about the app's own UI goes through here. The mini player talks to
/// the controller directly, so the two surfaces cannot disagree — they are
/// reading the same state.
///
/// Position and seeking are deliberately absent. Speech has no duration to
/// scrub through: an utterance takes as long as it takes, and the meaningful
/// unit is the chunk. Next and previous therefore move a verse or a paragraph,
/// which is also what they do in the app.
class SpeechAudioHandler extends BaseAudioHandler {
  SpeechAudioHandler(this._speech) {
    _remove = _speech.addListener(_broadcast);
  }

  final SpeechController _speech;
  late final void Function() _remove;

  /// Shown under the title on the lock screen. The translation, not the app —
  /// scripture is what is being read, and the WEB is what it is.
  static const _attribution = 'World English Bible';

  @override
  Future<void> play() => _speech.play();

  @override
  Future<void> pause() => _speech.pause();

  @override
  Future<void> stop() async {
    await _speech.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() => _speech.skip(1);

  @override
  Future<void> skipToPrevious() => _speech.skip(-1);

  /// Swiping the notification away means stop, not pause. The alternative is a
  /// voice still reading with no way left to silence it.
  @override
  Future<void> onNotificationDeleted() => stop();

  @override
  Future<void> onTaskRemoved() => stop();

  /// Republish everything the system shows, whenever the controller moves.
  void _broadcast(SpeechState state) {
    final source = state.source;

    if (source == null) {
      playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.idle,
          playing: false,
          controls: const [],
        ),
      );
      mediaItem.add(null);
      return;
    }

    mediaItem.add(
      MediaItem(
        id: source.id,
        title: source.title,
        artist: _attribution,
        // The line being spoken. It changes as the reading moves, which is the
        // only progress indicator a queue with no duration can offer.
        album: state.label ?? source.title,
      ),
    );

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (state.isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.skipToNext, MediaAction.skipToPrevious},
        // Previous, play/pause, next — the three that fit the collapsed
        // notification on Android.
        androidCompactActionIndices: const [0, 1, 2],
        processingState: state.isIdle
            ? AudioProcessingState.completed
            : AudioProcessingState.ready,
        playing: state.isPlaying,
        queueIndex: state.index,
        speed: state.rate,
      ),
    );
  }

  void dispose() => _remove();
}
