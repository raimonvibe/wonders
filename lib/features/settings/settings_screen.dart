import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../theme/app_bar_title.dart';
import '../../theme/app_theme.dart';
import '../../theme/metrics.dart';
import '../../theme/palette.dart';
import '../../theme/panel.dart';
import '../speech/listen_button.dart';
import '../speech/speakables.dart';
import '../speech/speech_settings_sheet.dart';
import 'licenses_tile.dart';
import 'maker_footer.dart';
import 'privacy_tile.dart';

/// Theme, reading size, and what the text is.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Stated once, so the bar's height is measured from the string it paints.
  static const _title = 'More';

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themeProvider);
    final theme = ref.read(themeProvider.notifier);
    final scale = ref.watch(fontScaleProvider);
    final lock = ref.watch(prefsProvider).themeLock;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppBarTitle.toolbarHeightFor(
          context,
          _title,
          actions: 1,
        ),
        title: const AppBarTitle(_title, actions: 1),
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
            _ThemePicker(
              selected: Palette.lockedOf(lock),
              onSelect: (palette) async {
                await theme.lockTo(palette);
                if (mounted) setState(() {});
              },
            ),
            const Caption(
              'Follow wears green in the Old Testament and blue in the New. '
              'Pin a colour to keep it on every page.',
            ),

            const Divider(),
            const _Heading('Reading size'),
            // The sample sits above the slider, not below it, so a thumb on the
            // track never covers the thing it is changing.
            _SizeSample(palette: palette),
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
              '${(scale * 100).round()}% — applies to every word in the app.',
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
            const PrivacyTile(),
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
/// superscript number, Merriweather at 18, the same line height — so what you
/// see here is what the chapter will look like, not an approximation of it.
///
/// Nothing here multiplies by the chosen size any more, and it must not: the
/// scale is in the MediaQuery over the whole app now, so this sample grows
/// because every Text does. Scaling it a second time by hand would make the
/// one widget whose job is to be accurate the only one that lies.
class _SizeSample extends StatelessWidget {
  const _SizeSample({required this.palette});

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
                  fontSize: 12,
                  fontFeatures: const [FontFeature.superscripts()],
                ),
              ),
              const TextSpan(
                text: 'In the beginning, God created the heavens and the '
                    'earth.',
              ),
            ],
          ),
          style: AppTheme.verseStyle(palette, fontSize: 18),
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

/// Follow plus every pin, as a pair of columns so four choices fit a phone
/// without the labels collapsing the way a four-segment button would.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.selected, required this.onSelect});

  /// Null is Follow.
  final Palette? selected;
  final Future<void> Function(Palette?) onSelect;

  @override
  Widget build(BuildContext context) {
    final options = <(String, Palette?, Gradient)>[
      ('Follow', null, Palette.followPreview),
      for (final palette in Palette.values)
        (palette.label, palette, palette.pageGradient),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, box) {
          final width = (box.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                SizedBox(
                  width: width,
                  child: _ThemeTile(
                    label: option.$1,
                    palette: option.$2,
                    gradient: option.$3,
                    selected: selected == option.$2,
                    onTap: () => onSelect(option.$2),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The gradient is the theme; the name sits under it in the colour the page
/// is already wearing, so a brown label is never asked to read on a green
/// ground.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.label,
    required this.palette,
    required this.gradient,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Palette? palette;
  final Gradient gradient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: palette == null ? 'Follow the testament' : '$label theme',
      excludeSemantics: true,
      child: Material(
        color: scheme.surface.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? Palette.gold : scheme.outline.withValues(alpha: 0.5),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Ink(
                height: 36,
                decoration: BoxDecoration(gradient: gradient),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
