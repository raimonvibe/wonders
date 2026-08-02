import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'speech_controller.dart';
import 'speech_voices.dart';

/// The voice, the speed, and how much of a wonder gets read.
///
/// Written as a plain column so the same widget serves the More tab and the
/// sheet the mini player opens — the settings a reader wants to change are
/// nearly always wanted *while* something is being read, and making them reach
/// the More tab for the speed slider would mean losing their place.
class SpeechSettings extends ConsumerWidget {
  const SpeechSettings({super.key, this.showReach = true});

  /// The card / passage / both switcher only means something where a wonder is
  /// in view, so the Bible tab's sheet leaves it out.
  final bool showReach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speech = ref.watch(speechProvider);
    final controller = ref.read(speechProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showReach) ...[
          const _Label('What to read'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<SpeechReach>(
              segments: [
                for (final reach in SpeechReach.values)
                  ButtonSegment(value: reach, label: Text(reach.label)),
              ],
              selected: {speech.reach},
              showSelectedIcon: false,
              onSelectionChanged: (s) => controller.setReach(s.first),
            ),
          ),
          const ListTile(
            dense: true,
            subtitle: Text(
              'Applies when you read a wonder aloud. The card is its written '
              'account; the passage is the chapter it happened in.',
            ),
          ),
        ],

        const _Label('Stop reading after'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              for (final option in SleepAfter.values)
                ChoiceChip(
                  label: Text(option.label),
                  selected: speech.sleepAfter == option,
                  onSelected: (_) => controller.setSleepAfter(option),
                ),
            ],
          ),
        ),
        const ListTile(
          dense: true,
          subtitle: Text(
            'The reading finishes the line it is on before it stops, so you '
            'are not cut off mid sentence.',
          ),
        ),

        const _Label('Speed'),
        _RateSlider(speech: speech, controller: controller),

        const _Label('Pitch'),
        Slider(
          value: speech.pitch,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          label: speech.pitch.toStringAsFixed(2),
          onChanged: controller.setPitch,
        ),

        const _Label('Voice'),
        _VoicePicker(speech: speech, controller: controller),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: OutlinedButton.icon(
            onPressed: speech.isIdle
                ? () => controller.preview(
                      'In the beginning, God created the heavens and the earth.',
                    )
                : null,
            icon: const Icon(Icons.volume_up_outlined),
            label: Text(
              speech.isIdle
                  ? 'Hear this voice'
                  : 'Stop the reading to try a voice',
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens the same settings as a sheet, from wherever speech is happening.
Future<void> showSpeechSettings(
  BuildContext context, {
  bool showReach = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: SpeechSettings(showReach: showReach),
      ),
    ),
  );
}

/// Speed as a multiple of normal, not as the engine's own number.
///
/// The engine's scale is not the same on the two platforms and is not
/// meaningful on either — SpeechController turns this multiplier into whatever
/// the device calls normal.
class _RateSlider extends StatelessWidget {
  const _RateSlider({required this.speech, required this.controller});

  final SpeechState speech;
  final SpeechController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          value: speech.rate,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          label: '${speech.rate.toStringAsFixed(2)}×',
          onChanged: controller.setRate,
        ),
        ListTile(
          dense: true,
          subtitle: Text(
            speech.rate == 1.0
                ? 'Normal speed.'
                : '${speech.rate.toStringAsFixed(2)}× normal speed. '
                    'Takes effect at the next line.',
          ),
        ),
      ],
    );
  }
}

class _VoicePicker extends StatelessWidget {
  const _VoicePicker({required this.speech, required this.controller});

  final SpeechState speech;
  final SpeechController controller;

  @override
  Widget build(BuildContext context) {
    if (!speech.ready) {
      return const ListTile(
        dense: true,
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Asking the device which voices it has…'),
      );
    }

    if (speech.voices.isEmpty) {
      return const ListTile(
        dense: true,
        subtitle: Text(
          'This device does not offer a voice list, so the system default is '
          'used. Speed and pitch still apply.',
        ),
      );
    }

    final groups = groupVoicesByLanguage(speech.voices);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: speech.voiceId,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final group in groups) ...[
            // Dart has no option-group in a DropdownButton, so the language is
            // a disabled row above its voices.
            DropdownMenuItem<String>(
              enabled: false,
              child: Text(
                group.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            for (final voice in group.voices)
              DropdownMenuItem<String>(
                value: voice.id,
                child: Text(voice.name, overflow: TextOverflow.ellipsis),
              ),
          ],
        ],
        onChanged: (id) {
          if (id == null) return;
          for (final voice in speech.voices) {
            if (voice.id == id) {
              controller.setVoice(voice);
              return;
            }
          }
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
