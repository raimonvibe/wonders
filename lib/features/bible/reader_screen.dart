import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bible.dart';
import '../../providers.dart';
import '../speech/listen_button.dart';
import '../speech/speakables.dart';
import '../speech/speech_chunk.dart';
import 'passage_view.dart';

/// One chapter, read straight through, with the neighbours a swipe away.
///
/// The Bible tab's leaf. It renders the same [PassageView] a wonder's passage
/// page does, with no highlight — the difference between reading a chapter and
/// being sent to one is a parameter, not a second implementation.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.chapterId});

  final String chapterId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late String _chapterId = widget.chapterId;
  Chapter? _chapter;
  Chapter? _previous;
  Chapter? _next;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(bibleProvider);
    final chapter = await repo.chapter(_chapterId);
    if (chapter == null || !mounted) return;

    final previous = await repo.adjacentChapter(chapter, offset: -1);
    final next = await repo.adjacentChapter(chapter, offset: 1);
    if (!mounted) return;

    setState(() {
      _chapter = chapter;
      _previous = previous;
      _next = next;
    });

    // Losing the reader's place costs them one tap; blocking the paint to
    // record it would cost every reader a stutter on every chapter turn. The
    // controller persists it and is what the Bible tab's resume card watches.
    ref.read(lastChapterProvider.notifier).set(chapter.id);
    final book = await repo.book(chapter.bookId);
    if (book != null && mounted) {
      ref.read(themeProvider.notifier).followTestament(book.testament);
    }
  }

  void _goTo(Chapter chapter) {
    setState(() {
      _chapterId = chapter.id;
      _chapter = null;
    });
    _load();
  }

  /// The chapter on screen, as speech. Built on demand rather than kept beside
  /// the chapter, because most readings never happen and the verses are a
  /// query.
  Future<Speakable?> _speakable() async {
    final chapter = _chapter;
    if (chapter == null) return null;
    final verses = await ref.read(bibleProvider).versesIn(chapter.id);
    if (verses.isEmpty) return null;
    return Speakables.chapter(chapter, verses);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_chapter?.reference ?? ''),
        actions: [
          ListenButton(
            sourceId: Speakables.chapterKey(_chapterId),
            source: _speakable,
            tooltip: 'Read this chapter aloud',
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.pageGradient),
        child: GestureDetector(
          // Horizontal flings move between chapters, including across book
          // boundaries — Genesis 50 swipes into Exodus 1.
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            final target = velocity < -200
                ? _next
                : velocity > 200
                    ? _previous
                    : null;
            // Null at the two ends of the Bible: the fling is simply ignored.
            if (target != null) _goTo(target);
          },
          child: PassageView(chapterId: _chapterId),
        ),
      ),
      bottomNavigationBar: ChapterTurnBar(
        previous: _previous,
        next: _next,
        onGo: _goTo,
      ),
    );
  }
}

/// The chapter either side, named.
///
/// Two things were wrong with the row this replaces. A reference is as long as
/// its book — "1 Chronicles 29" twice over does not fit a phone, and at a
/// raised text size it overflows well before that, on the one screen a reader
/// raises their text size to use. And at the ends of the Bible the missing
/// neighbour left a disabled chevron floating with no label beside it, which
/// looks like a button that failed to load rather than an edge you have
/// reached.
///
/// Lifted out of [ReaderScreen] so it can be laid out in a test without the
/// 7.5 MB scripture database behind it.
class ChapterTurnBar extends StatelessWidget {
  const ChapterTurnBar({
    super.key,
    required this.previous,
    required this.next,
    required this.onGo,
  });

  /// Null at Genesis 1 and at Revelation 22 respectively.
  final Chapter? previous;
  final Chapter? next;

  final ValueChanged<Chapter> onGo;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        children: [
          Expanded(
            child: _end(Alignment.centerLeft, previous, Icons.chevron_left),
          ),
          Expanded(
            child: _end(
              Alignment.centerRight,
              next,
              Icons.chevron_right,
              iconAtEnd: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Half the bar is all a reference can ever have, so it is allowed one line
  /// and told to trail off rather than to grow.
  Widget _end(
    Alignment alignment,
    Chapter? chapter,
    IconData icon, {
    bool iconAtEnd = false,
  }) {
    if (chapter == null) return const SizedBox.shrink();
    return Align(
      alignment: alignment,
      child: TextButton.icon(
        onPressed: () => onGo(chapter),
        icon: Icon(icon),
        iconAlignment: iconAtEnd ? IconAlignment.end : IconAlignment.start,
        label: Text(
          chapter.reference,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
