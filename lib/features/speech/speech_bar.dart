import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/metrics.dart';
import '../../theme/palette.dart';
import 'speech_controller.dart';
import 'speech_settings_sheet.dart';

/// The transport, docked above the bottom nav.
///
/// Speech is the one thing in this app that carries on after you leave the
/// screen that started it, so its controls have to live somewhere that does the
/// same. Without this, pausing a chapter you started in the Bible tab means
/// finding your way back to it first — and the reader who most needs read-aloud
/// is the one least able to do that.
///
/// It shows nothing at all until something is loaded, so it costs no room on a
/// phone that is only being read from.
class SpeechBar extends ConsumerWidget {
  const SpeechBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speech = ref.watch(speechProvider);
    final controller = ref.read(speechProvider.notifier);
    final palette = ref.watch(themeProvider);
    final source = speech.source;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      child: source == null
          ? const SizedBox(width: double.infinity)
          : Material(
              color: palette.shade800,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: speech.progress,
                    minHeight: 2,
                    backgroundColor: palette.shade700,
                    valueColor: const AlwaysStoppedAnimation(Palette.accent),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                source.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: palette.shade50,
                                ),
                              ),
                              Text(
                                _status(speech),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.shade300,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Back one line',
                          visualDensity: VisualDensity.compact,
                          iconSize: speechIconSize,
                          padding: const EdgeInsets.all(speechIconPad),
                          onPressed: speech.index == 0
                              ? null
                              : () => controller.skip(-1),
                          icon: const Icon(Icons.skip_previous),
                        ),
                        IconButton(
                          tooltip: speech.isPlaying ? 'Pause' : 'Play',
                          visualDensity: VisualDensity.compact,
                          iconSize: speechIconSize,
                          padding: const EdgeInsets.all(speechIconPad),
                          onPressed: () {
                            if (speech.isPlaying) {
                              controller.pause();
                            } else if (speech.isPaused) {
                              controller.resume();
                            } else {
                              // Finished: the source is still loaded, so the
                              // obvious meaning of Play is "again".
                              controller.start(source);
                            }
                          },
                          icon: Icon(
                            speech.isPlaying
                                ? Icons.pause
                                : speech.isPaused
                                    ? Icons.play_arrow
                                    : Icons.replay,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Forward one line',
                          visualDensity: VisualDensity.compact,
                          iconSize: speechIconSize,
                          padding: const EdgeInsets.all(speechIconPad),
                          onPressed: speech.index >= source.length - 1
                              ? null
                              : () => controller.skip(1),
                          icon: const Icon(Icons.skip_next),
                        ),
                        IconButton(
                          tooltip: speech.isSleeping
                              ? 'Stopping in ${speech.sleepAfter.label}'
                              : 'Voice, speed and sleep timer',
                          visualDensity: VisualDensity.compact,
                          iconSize: speechIconSize,
                          padding: const EdgeInsets.all(speechIconPad),
                          onPressed: () => showSpeechSettings(context),
                          // A set timer is the one speech setting with a
                          // consequence you would want to see without opening
                          // anything.
                          icon: Icon(
                            speech.isSleeping ? Icons.bedtime : Icons.tune,
                          ),
                          color: speech.isSleeping ? Palette.accent : null,
                        ),
                        IconButton(
                          tooltip: 'Stop',
                          visualDensity: VisualDensity.compact,
                          iconSize: speechIconSize,
                          padding: const EdgeInsets.all(speechIconPad),
                          onPressed: controller.stop,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  static String _status(SpeechState speech) {
    final position = '${speech.index + 1} of ${speech.source?.length ?? 0}';
    if (speech.isPaused) return 'Paused · $position';
    if (speech.isIdle) return 'Finished';
    return '${speech.label ?? ''} · $position';
  }
}
