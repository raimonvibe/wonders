import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/metrics.dart';
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
          const Caption(
            'Applies when you read a wonder aloud. The card is its written '
            'account; the passage is the chapter it happened in.',
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
        const Caption(
          'The reading finishes the line it is on before it stops, so you '
          'are not cut off mid sentence.',
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
          // Sliding only — see the note on _RateSlider.
          allowedInteraction: SliderInteraction.slideOnly,
          // Without this a screen reader reads the raw number: "one point four".
          // In an app whose whole point is being listened to, the one control a
          // blind reader is most likely to reach for should say what it does.
          semanticFormatterCallback: _pitchLabel,
          onChanged: controller.setPitch,
        ),
        // Pitch was the one control on this page with no line under it: a bare
        // slider, no value, nothing saying which end is which.
        Caption(
          speech.pitch == 1.0
              ? 'Natural pitch.'
              : '${_pitchLabel(speech.pitch)}. Takes effect at the next line.',
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

/// "Higher than natural, 1.40×" — a pitch as something other than a number.
String _pitchLabel(double pitch) {
  final times = '${pitch.toStringAsFixed(2)}×';
  if (pitch == 1.0) return 'Natural pitch';
  return pitch > 1.0 ? 'Higher than natural, $times' : 'Lower than natural, $times';
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
///
/// Sliding only, no tap. This whole column lives inside a scroll view — the
/// More tab's list and the mini player's sheet both — and a track that reaches
/// the full width of the screen is most of what a thumb lands on while
/// scrolling past it. A flick shorter than the touch slop is delivered as a
/// tap, and a tap on a `tapAndSlide` track jumps the value to wherever the
/// finger was: scroll past this control carelessly and the reading is suddenly
/// at 1.60×, with nothing on screen to say why. Sliding is a deliberate enough
/// gesture that it never happens by accident, and it still works anywhere on
/// the track, so nothing is lost but the misfire.
class _RateSlider extends StatelessWidget {
  const _RateSlider({required this.speech, required this.controller});

  final SpeechState speech;
  final SpeechController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      // The page's own column stretches, so a caption nested in this one has to
      // as well — otherwise "Normal speed." centres itself under the speed
      // slider while "Natural pitch." sits against the margin under the next
      // one, and the two lines look like they belong to different screens.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Slider(
          value: speech.rate,
          min: 0.5,
          max: 2.0,
          divisions: 15,
          label: '${speech.rate.toStringAsFixed(2)}×',
          allowedInteraction: SliderInteraction.slideOnly,
          semanticFormatterCallback: (rate) =>
              rate == 1.0 ? 'Normal speed' : '${rate.toStringAsFixed(2)} times normal speed',
          onChanged: controller.setRate,
        ),
        Caption(
          speech.rate == 1.0
              ? 'Normal speed.'
              : '${speech.rate.toStringAsFixed(2)}× normal speed. '
                  'Takes effect at the next line.',
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
        // The open list and the closed field want different things: the list is
        // grouped, so a row need only say which voice; the field has no heading
        // above it, so it has to say the language too. Same order and length as
        // [items], group headings included, or the field shows the wrong row.
        selectedItemBuilder: (context) => [
          for (final group in groups) ...[
            const SizedBox.shrink(),
            for (final voice in group.voices)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  voice.pickerLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ],
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
                child: Text(
                  voice.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
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

