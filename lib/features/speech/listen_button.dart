import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/metrics.dart';
import 'speech_chunk.dart';

/// The Listen control, for an app bar.
///
/// One button on every screen that has something to say, which is what makes
/// read-aloud a feature of the app rather than of one screen.
///
/// Building the queue is deferred to [source] because scripture has to come out
/// of the database first, and doing that on every rebuild would query a chapter
/// to draw an icon.
class ListenButton extends ConsumerStatefulWidget {
  const ListenButton({
    super.key,
    required this.sourceId,
    required this.source,
    this.from,
    this.tooltip = 'Read aloud',
  });

  /// The id [Speakables] gives this screen's material. Compared against what is
  /// loaded, so the button can show a pause icon for its own material and a
  /// play icon for anybody else's.
  final String sourceId;

  /// Builds the queue, when it is actually needed. Returning null means there
  /// is nothing to read — the button reports it rather than going silent.
  final Future<Speakable?> Function() source;

  /// Which chunk to begin at. Defaults to the first.
  final int Function(Speakable)? from;

  final String tooltip;

  @override
  ConsumerState<ListenButton> createState() => _ListenButtonState();
}

class _ListenButtonState extends ConsumerState<ListenButton> {
  bool _busy = false;

  Future<void> _onPressed() async {
    final speech = ref.read(speechProvider);
    final controller = ref.read(speechProvider.notifier);

    // Already ours: this is a transport control, not a new request.
    if (speech.isSource(widget.sourceId)) {
      if (speech.isPlaying) return controller.pause();
      if (speech.isPaused) return controller.resume();
    }

    // Something else is still talking (or paused). Stop it from *this* page —
    // otherwise the reader has to find the screen that started it before they
    // can silence leftover audio.
    if (speech.source != null &&
        !speech.isSource(widget.sourceId) &&
        !speech.isIdle) {
      return controller.stop();
    }

    if (_busy) return;
    setState(() => _busy = true);
    try {
      final source = await widget.source();
      if (!mounted) return;
      if (source == null || source.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('There is nothing to read here.')),
        );
        return;
      }
      await controller.start(source, from: widget.from?.call(source) ?? 0);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Select only what paints the icon. Watching the whole state rebuilt the
    // bar on every chunk for no reason, and on a slow device that could leave
    // the pause glyph up a frame after status had already flipped.
    final playing = ref.watch(
      speechProvider.select((s) => s.isSource(widget.sourceId) && s.isPlaying),
    );
    final paused = ref.watch(
      speechProvider.select((s) => s.isSource(widget.sourceId) && s.isPaused),
    );
    final foreignActive = ref.watch(
      speechProvider.select(
        (s) =>
            s.source != null &&
            !s.isSource(widget.sourceId) &&
            !s.isIdle,
      ),
    );

    final IconData icon;
    final String tooltip;
    if (playing) {
      icon = Icons.pause_circle_outline;
      tooltip = 'Pause';
    } else if (paused) {
      icon = Icons.play_circle_outline;
      tooltip = 'Resume';
    } else if (foreignActive) {
      icon = Icons.stop_circle_outlined;
      tooltip = 'Stop reading';
    } else {
      icon = Icons.headphones_outlined;
      tooltip = widget.tooltip;
    }

    return IconButton(
      tooltip: tooltip,
      // Bigger than Material's 24 for the reason given on [speechIconSize].
      // No padding override here, unlike the mini player: an app bar's action
      // has room, and 28 plus the default 8 comes to 44, still inside the 48
      // this button already reserved as a tap target. Nothing moves.
      iconSize: speechIconSize,
      onPressed: _busy ? null : _onPressed,
      icon: _busy
          // Sized to the icon it stands in for, so the bar does not twitch
          // between pressing Listen and the first word.
          ? const SizedBox(
              width: speechIconSize,
              height: speechIconSize,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      // Speaking is the one thing on screen that keeps happening after you look
      // away, so it gets a colour while it is happening — including leftover
      // audio from another screen, which this button can now stop.
      color: playing || paused || foreignActive
          ? Theme.of(context).colorScheme.secondary
          : null,
    );
  }
}
