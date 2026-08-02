import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../models/bible.dart';
import '../../models/mark.dart';
import '../../models/passage_ref.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../library/mark_sheet.dart';
import '../speech/speakables.dart';

/// One chapter of scripture, optionally with a verse range picked out.
///
/// This is the piece that makes "separate screens" survivable. The Bible tab
/// renders it with [highlight] null; a wonder's passage page renders the same
/// widget with the card's range — same typography, same behaviour, hosted in
/// whichever tab the reader came from. There is exactly one reader in this app,
/// which is also why everything the reader can do to a verse is here.
///
/// Three things can mark a verse, and they have to stay tellable apart:
///
/// | Mark              | Looks like             | Lasts         |
/// | ---               | ---                    | ---           |
/// | the wonder's range| the page ground, lifted| the visit     |
/// | being spoken      | the accent, moving     | the utterance |
/// | the reader's own  | their chosen colour    | for good      |
///
/// ## Why this is not a ListView
///
/// Both of the automatic scrolls here have to reach a verse that is usually
/// below the fold, and a lazy `ListView` has not built those. `GlobalKey`
/// plus `Scrollable.ensureVisible` therefore fails in exactly the case it
/// exists for — `currentContext` is null and the call returns silently, so
/// opening a wonder's passage landed on verse 1 and following a reading gave up
/// as soon as the voice moved past the last built verse. Index-based scrolling
/// does not need the target built first, which is the whole reason
/// scrollable_positioned_list is a dependency.
class PassageView extends ConsumerStatefulWidget {
  const PassageView({
    super.key,
    required this.chapterId,
    this.highlight,
    this.autoScrollToHighlight = true,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 40),
  });

  final String chapterId;

  /// Verses to mark, when the reader arrived from a wonder card.
  final PassageRef? highlight;

  /// Open on the first highlighted verse rather than at the top.
  final bool autoScrollToHighlight;

  final EdgeInsets padding;

  /// Where in [verses] the cited range begins, or 0 when there is no citation.
  ///
  /// By index, not by verse number. The two differ by one in every chapter, and
  /// by more in any chapter whose numbering has a gap, so using the number as a
  /// position lands the reader a verse or two off — near enough to look
  /// deliberate and wrong every time.
  static int indexOfFirstVerse(List<Verse> verses, PassageRef? highlight) {
    if (highlight == null) return 0;
    final index = verses.indexWhere((v) => v.number == highlight.firstVerse);
    return index < 0 ? 0 : index;
  }

  @override
  ConsumerState<PassageView> createState() => _PassageViewState();
}

class _PassageViewState extends ConsumerState<PassageView> {
  late Future<(Chapter?, List<Verse>)> _chapter;
  final _scroll = ItemScrollController();

  /// Where the cited range starts, once the verses are known. Handed to
  /// [ScrollablePositionedList.initialScrollIndex], so the passage *opens*
  /// there rather than opening at verse 1 and then travelling — no flash of the
  /// wrong text, and nothing to go wrong if the reader scrolls immediately.
  int _openAt = 0;

  /// The verse we have already followed. Without it every rebuild would drag
  /// the list back to the spoken verse, including the ones caused by the reader
  /// scrolling away on purpose.
  String? _followedAnchor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PassageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterId != widget.chapterId) {
      _followedAnchor = null;
      _load();
    }
  }

  /// The chapter comes along with the verses because a mark needs its
  /// reference — "Exodus 14:21" is what the library lists, and building it from
  /// the id would mean this widget knowing how book names are spelt.
  void _load() {
    final repo = ref.read(bibleProvider);
    _chapter = () async {
      final chapter = await repo.chapter(widget.chapterId);
      final verses = await repo.versesIn(widget.chapterId);
      _openAt = widget.autoScrollToHighlight
          ? PassageView.indexOfFirstVerse(verses, widget.highlight)
          : 0;
      return (chapter, verses);
    }();
  }

  /// Keep the verse being spoken on screen, once per verse.
  void _followSpokenVerse(List<Verse> verses, String? anchor) {
    if (anchor == null || anchor == _followedAnchor) return;
    _followedAnchor = anchor;

    final index = verses.indexWhere(
      (v) => Speakables.verseAnchor(widget.chapterId, v.number) == anchor,
    );
    if (index < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.isAttached) return;
      _scroll.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        // A third of the way down, so the line being read has the lines it is
        // about to reach visible underneath it.
        alignment: 0.3,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themeProvider);
    final scale = ref.watch(fontScaleProvider);
    final marks = ref.watch(marksInChapterProvider(widget.chapterId));

    // Only the anchor, so a chapter is not rebuilt for a pause or a rate
    // change — this runs once per verse spoken.
    final spokenAnchor = ref.watch(speechProvider.select((s) => s.anchor));
    final speakingHere = spokenAnchor != null &&
        spokenAnchor.startsWith('verse:${widget.chapterId}:');

    return FutureBuilder<(Chapter?, List<Verse>)>(
      future: _chapter,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Message(
            'That chapter could not be opened.\n${snapshot.error}',
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final (chapter, verses) = data;
        if (verses.isEmpty) {
          return const _Message('That chapter is empty.');
        }

        if (speakingHere) {
          _followSpokenVerse(verses, spokenAnchor);
        } else {
          _followedAnchor = null;
        }

        final highlight = widget.highlight;

        return ScrollablePositionedList.builder(
          // Keyed by chapter so turning the page builds a fresh list.
          // initialScrollIndex is only honoured on a list's first build, and
          // without this the reader would carry their offset from Genesis 50
          // into Exodus 1 and land halfway down it.
          key: ValueKey(widget.chapterId),
          itemScrollController: _scroll,
          initialScrollIndex: _openAt,
          // Not hard against the top: a highlighted verse flush with the app
          // bar reads as the start of the chapter rather than as a place
          // somewhere inside it.
          initialAlignment: 0.12,
          padding: widget.padding,
          itemCount: verses.length,
          itemBuilder: (context, index) {
            final verse = verses[index];
            final inRange = highlight?.highlights(verse.number) ?? false;
            final anchor =
                Speakables.verseAnchor(widget.chapterId, verse.number);
            final isSpoken = speakingHere && anchor == spokenAnchor;
            final mark = marks[verse.number];
            final decorated = inRange || isSpoken || mark != null;

            final verseWidget = AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: decorated
                  ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
                  : EdgeInsets.zero,
              decoration: _decorationFor(
                palette: palette,
                inRange: inRange,
                isSpoken: isSpoken,
                mark: mark,
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${verse.number} ',
                      style: TextStyle(
                        color: palette.shade400,
                        fontSize: 12 * scale,
                        fontFeatures: const [FontFeature.superscripts()],
                      ),
                    ),
                    TextSpan(text: verse.text),
                    // A note is worth knowing about without opening anything,
                    // and the colour alone cannot say there is one.
                    if (mark?.hasNote ?? false)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.sticky_note_2_outlined,
                            size: 14 * scale,
                            color: mark!.colour.edge,
                          ),
                        ),
                      ),
                  ],
                ),
                style: AppTheme.verseStyle(palette, fontSize: 18 * scale),
              ),
            );

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Press and hold to keep a verse. One gesture for marking,
              // re-colouring, annotating and letting go — see showMarkSheet.
              onLongPress: chapter == null
                  ? null
                  : () => showMarkSheet(
                        context,
                        verse: verse,
                        reference: '${chapter.reference}:${verse.number}',
                      ),
              // A tap only means something while this chapter is being read,
              // where it moves the reading to the verse you tapped.
              onTap: speakingHere
                  ? () => ref.read(speechProvider.notifier).seekToAnchor(anchor)
                  : null,
              child: verseWidget,
            );
          },
        );
      },
    );
  }

  /// Which of the three marks wins.
  ///
  /// The spoken verse takes precedence over everything: it is the only one that
  /// moves, it is gone in a second, and losing sight of it is what makes
  /// following along impossible. The reader's own colour outranks a wonder's
  /// range because they chose it and the range came with the link.
  static BoxDecoration? _decorationFor({
    required Palette palette,
    required bool inRange,
    required bool isSpoken,
    required Mark? mark,
  }) {
    if (!inRange && !isSpoken && mark == null) return null;

    final Color fill;
    final Color edge;
    if (isSpoken) {
      fill = Palette.accent.withValues(alpha: 0.18);
      edge = Palette.accent;
    } else if (mark != null) {
      fill = mark.colour.fill;
      edge = mark.colour.edge;
    } else {
      fill = palette.shade700.withValues(alpha: 0.55);
      edge = Palette.accent;
    }

    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(8),
      border: Border(
        left: BorderSide(color: edge, width: isSpoken ? 4 : 3),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}
