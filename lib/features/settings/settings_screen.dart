import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/wonder.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/metrics.dart';
import '../../theme/palette.dart';
import '../../theme/panel.dart';
import '../speech/listen_button.dart';
import '../speech/speakables.dart';
import '../speech/speech_settings_sheet.dart';
import 'licenses_tile.dart';
import 'maker_footer.dart';

/// Theme, reading size, and what the text is.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themeProvider);
    final theme = ref.read(themeProvider.notifier);
    final scale = ref.watch(fontScaleProvider);
    final lock = ref.watch(prefsProvider).themeLock;

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        actions: [
          ListenButton(
            sourceId: Speakables.aboutId,
            source: () async => Speakables.about(
              wonderCount: ref.read(wondersProvider).count,
            ),
            tooltip: 'Read this page aloud',
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.pageGradient),
        child: ListView(
          children: [
            const _Heading('Yours'),
            Consumer(
              builder: (context, ref, _) {
                final kept = ref.watch(marksProvider).length;
                return ListTile(
                  leading: const Icon(Icons.bookmark_border),
                  title: const Text('Kept verses'),
                  subtitle: Text(
                    kept == 0
                        ? 'Press and hold a verse while reading to keep it.'
                        : kept == 1
                            ? '1 verse marked.'
                            : '$kept verses marked.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/more/library'),
                );
              },
            ),

            const Divider(),
            const _Heading('Theme'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'follow', label: Text('Follow')),
                  ButtonSegment(value: 'old', label: Text('Green')),
                  ButtonSegment(value: 'new', label: Text('Blue')),
                ],
                selected: {lock ?? 'follow'},
                showSelectedIcon: false,
                onSelectionChanged: (selection) async {
                  final choice = selection.first;
                  await theme.lockTo(
                    choice == 'follow' ? null : Testament.parse(choice),
                  );
                  if (mounted) setState(() {});
                },
              ),
            ),
            const Caption(
              'Follow means green in the Old Testament, blue in the New.',
            ),

            const Divider(),
            const _Heading('Reading size'),
            // The sample sits above the slider, not below it, so a thumb on the
            // track never covers the thing it is changing.
            _SizeSample(scale: scale, palette: palette),
            Slider(
              value: scale,
              min: 0.85,
              max: 1.6,
              divisions: 15,
              label: '${(scale * 100).round()}%',
              // Sliding only, for the reason given on _RateSlider: this list
              // scrolls, and a tap on a full-width track is what a scroll that
              // fell short of the touch slop turns into.
              allowedInteraction: SliderInteraction.slideOnly,
              semanticFormatterCallback: (value) =>
                  'Reading size ${(value * 100).round()} percent',
              onChanged: ref.read(fontScaleProvider.notifier).set,
            ),
            Caption(
              '${(scale * 100).round()}% — applies everywhere you read '
              'scripture.',
            ),

            const Divider(),
            const _Heading('Read aloud'),
            // The same widget the mini player's sheet shows, so there is one
            // place these settings are defined and two places to reach them.
            const SpeechSettings(),

            const Divider(),
            const _Heading('About'),
            const ListTile(
              title: Text('World English Bible'),
              subtitle: Text(
                'Public domain. All 66 books ship with the app, so reading '
                'and search work with no connection at all.',
              ),
            ),
            ListTile(
              title: const Text('Wonders'),
              subtitle: Text(
                '${ref.watch(wondersProvider).count} cards, each checked '
                'against the passage it cites.',
              ),
            ),
            const LicensesTile(),

            const Divider(),
            const MakerFooter(),
          ],
        ),
      ),
    );
  }
}

/// A real verse at the size being chosen.
///
/// The setting always applied instantly; there was simply nothing on this
/// screen rendered at that size, so the reader had to leave, look, and come
/// back to judge it. This is the same widget tree PassageView builds — the
/// superscript number, Merriweather at `18 * scale`, the same line height — so
/// what you see here is what the chapter will look like, not an approximation
/// of it.
class _SizeSample extends StatelessWidget {
  const _SizeSample({required this.scale, required this.palette});

  final double scale;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Panel(
        palette: palette,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '1 ',
                style: TextStyle(
                  color: palette.shade400,
                  fontSize: 12 * scale,
                  fontFeatures: const [FontFeature.superscripts()],
                ),
              ),
              const TextSpan(
                text: 'In the beginning, God created the heavens and the '
                    'earth.',
              ),
            ],
          ),
          style: AppTheme.verseStyle(palette, fontSize: 18 * scale),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}
