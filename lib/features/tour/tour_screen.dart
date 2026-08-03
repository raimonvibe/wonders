import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bible.dart';
import '../../models/wonder.dart';
import '../../providers.dart';
import '../../theme/metrics.dart';
import '../speech/listen_button.dart';
import '../speech/speakables.dart';
import '../speech/speech_chunk.dart';
import '../speech/speech_controller.dart' show SpeechReach;
import '../wonders/wonder_card_body.dart';

/// The guided tour: fourteen wonders walked in order.
///
/// SCAFFOLD. The shape is here — a step at a time, resumable, and now narrated
/// — but the step list is still the whole ranked shortlist rather than the
/// curated fourteen from ../../lib/miraclesTour.ts. Porting that is the next
/// piece of work: export it alongside the catalog in scripts/export-wonders.js,
/// then read it here instead of calling startHere().
class TourScreen extends ConsumerStatefulWidget {
  const TourScreen({super.key});

  @override
  ConsumerState<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends ConsumerState<TourScreen> {
  late final PageController _pages =
      PageController(initialPage: ref.read(prefsProvider).tourStep);

  @override
  void initState() {
    super.initState();
    // Narrate the step the tour resumes on, not just the ones stepped onto
    // afterwards — otherwise turning narration on and reopening the tour is
    // silent until you swipe.
    WidgetsBinding.instance.addPostFrameCallback((_) => _narrateIfWanted());
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<Wonder> get _steps => ref.read(wondersProvider).startHere(limit: 14);

  Wonder? get _currentStep {
    final steps = _steps;
    final index = ref.read(prefsProvider).tourStep;
    if (index < 0 || index >= steps.length) return null;
    return steps[index];
  }

  /// The step on screen, at whatever reach the reader has chosen.
  Future<Speakable?> _speakable() async {
    final wonder = _currentStep;
    if (wonder == null) return null;

    final repo = ref.read(wondersProvider);
    final reach = ref.read(speechProvider).reach;
    if (reach == SpeechReach.card) return Speakables.card(wonder, repo);

    final bible = ref.read(bibleProvider);
    final chapterId = wonder.passage.chapterId;
    final Chapter? chapter = await bible.chapter(chapterId);
    final verses =
        chapter == null ? const <Verse>[] : await bible.versesIn(chapterId);

    return Speakables.forReach(
      reach,
      wonder: wonder,
      repo: repo,
      chapter: chapter,
      verses: verses,
    );
  }

  String _sourceId(Wonder wonder) => switch (ref.watch(speechProvider).reach) {
        SpeechReach.card => Speakables.cardId(wonder),
        SpeechReach.passage =>
          Speakables.chapterKey(wonder.passage.chapterId),
        SpeechReach.both => Speakables.bothId(wonder),
      };

  /// Speak the new step, if the reader asked for the tour to narrate itself.
  Future<void> _narrateIfWanted() async {
    if (!mounted) return;
    if (!ref.read(speechProvider).autoNarrateTour) return;
    final source = await _speakable();
    if (!mounted || source == null) return;
    await ref.read(speechProvider.notifier).start(source);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themeProvider);
    final steps = ref.watch(wondersProvider).startHere(limit: 14);
    final step = ref.watch(prefsProvider).tourStep;
    final narrating = ref.watch(speechProvider).autoNarrateTour;
    final current = step >= 0 && step < steps.length ? steps[step] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('The tour'),
        actions: [
          IconButton(
            tooltip: narrating
                ? 'Stop reading each step automatically'
                : 'Read each step automatically',
            isSelected: narrating,
            selectedIcon: const Icon(Icons.record_voice_over),
            icon: const Icon(Icons.record_voice_over_outlined),
            onPressed: () {
              final next = !narrating;
              ref.read(speechProvider.notifier).setAutoNarrateTour(next);
              if (next) {
                _narrateIfWanted();
              } else {
                ref.read(speechProvider.notifier).stop();
              }
            },
          ),
          if (current != null)
            ListenButton(
              sourceId: _sourceId(current),
              source: _speakable,
              tooltip: 'Read this step aloud',
            ),
        ],
        // How far in you are, in words as well as in fill. A four-pixel bar can
        // say "about a fifth"; it cannot say "step 3 of 14", and 14 is a number
        // a reader deciding whether to start wants to know. Measured rather
        // than guessed for the same reason the grids are — a PreferredSize is a
        // hard height, and a hard height is an overflow at a raised text size.
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            gridTileExtent(context, titleLines: 0, subtitleLines: 1, chrome: 10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    steps.isEmpty
                        ? ''
                        : 'Step ${step + 1} of ${steps.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              LinearProgressIndicator(
                value: steps.isEmpty ? 0 : (step + 1) / steps.length,
              ),
            ],
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.pageGradient),
        child: PageView.builder(
          controller: _pages,
          itemCount: steps.length,
          onPageChanged: (index) {
            ref.read(prefsProvider).setTourStep(index);
            ref
                .read(themeProvider.notifier)
                .followTestament(steps[index].testament);
            setState(() {});
            _narrateIfWanted();
          },
          itemBuilder: (context, index) =>
              WonderCardBody(wonder: steps[index]),
        ),
      ),
      // The two ways on.
      //
      // The tour was swipeable and nothing else: a card that scrolls vertically
      // gives no hint that it also moves sideways, so a reader could open the
      // tour, read one wonder and never learn there were thirteen more. Same
      // shape as the reader's chapter-turn bar, because it is the same action.
      bottomNavigationBar: steps.isEmpty
          ? null
          : BottomAppBar(
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: step == 0 ? null : () => _turn(-1),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Back'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed:
                            step >= steps.length - 1 ? null : () => _turn(1),
                        icon: const Icon(Icons.chevron_right),
                        iconAlignment: IconAlignment.end,
                        label: const Text('Next'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Move one step. Animated rather than jumped, so a tap and a swipe arrive
  /// at the same place the same way — and `onPageChanged` does the recording,
  /// the repaint and the narration for both.
  void _turn(int by) => _pages.animateToPage(
        _pages.page!.round() + by,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
}
