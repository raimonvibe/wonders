import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/bible.dart';
import '../../models/wonder.dart' show Testament;
import '../../providers.dart';
import '../../theme/app_bar_title.dart';
import '../../theme/metrics.dart';
import '../../theme/palette.dart';
import '../../theme/states.dart';
import '../speech/listen_button.dart';
import '../speech/speakables.dart';
import '../speech/spoken_follow.dart';

/// All 66 books, Old Testament then New.
///
/// The website sizes this grid with container queries so it works in the
/// docked pane; on a phone there is only one pane, so a plain responsive grid
/// is the honest translation.
///
/// While Listen is reading this page, the book being spoken is tinted and kept
/// on screen.
class BookListScreen extends ConsumerStatefulWidget {
  const BookListScreen({super.key});

  @override
  ConsumerState<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends ConsumerState<BookListScreen> {
  late final Future<List<Book>> _books = ref.read(bibleProvider).books();
  final _scroll = ScrollController();
  final _bookKeys = <String, GlobalKey>{};

  /// The anchor we have already followed. Without it every rebuild would drag
  /// the grid back to the spoken book.
  String? _followedAnchor;

  /// Stated once, so the bar's height is measured from the string it paints.
  static const _title = 'The Bible';

  GlobalKey _keyFor(String bookId) =>
      _bookKeys.putIfAbsent(bookId, GlobalKey.new);

  void _followSpoken(String? anchor) {
    if (anchor == null) {
      _followedAnchor = null;
      return;
    }
    if (anchor == _followedAnchor) return;
    _followedAnchor = anchor;

    if (!anchor.startsWith('book:')) return;
    final key = _keyFor(anchor.substring('book:'.length));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ensureSpokenVisible(key);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themeProvider);
    final spokenAnchor = ref.watch(
      speechProvider.select((s) {
        if (!s.isSource(Speakables.booksId)) return null;
        return s.anchor;
      }),
    );
    _followSpoken(spokenAnchor);

    return Scaffold(
      appBar: AppBar(
        // Two actions here rather than one, so the title has 48 pt less to
        // break in and the bar is measured against that.
        toolbarHeight: AppBarTitle.toolbarHeightFor(
          context,
          _title,
          actions: 2,
        ),
        title: const AppBarTitle(_title, actions: 2),
        actions: [
          ListenButton(
            sourceId: Speakables.booksId,
            source: () async => Speakables.books(await _books),
            tooltip: 'Read the book list aloud',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search the text',
            onPressed: () => showSearch(
              context: context,
              delegate: _BibleSearchDelegate(ref),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.pageGradient),
        child: FutureBuilder<List<Book>>(
          future: _books,
          builder: (context, snapshot) {
            final books = snapshot.data;
            if (books == null) {
              return const Loading('Opening the Bible');
            }
            final old = books.where((b) => b.testament == Testament.old);
            final current = books.where((b) => b.testament == Testament.aNew);

            return ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                const _ResumeCard(),
                _Heading('Old Testament', count: old.length),
                _BookGrid(
                  books: old.toList(),
                  spokenAnchor: spokenAnchor,
                  keyFor: _keyFor,
                ),
                const SizedBox(height: 28),
                _Heading('New Testament', count: current.length),
                _BookGrid(
                  books: current.toList(),
                  spokenAnchor: spokenAnchor,
                  keyFor: _keyFor,
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The chapter you were last reading, offered back.
///
/// The Wonders tab has had this since it was written. Without it here, opening
/// the Bible tab twenty chapters into Isaiah meant the grid of all 66 books and
/// three taps to get back — the resume state was being recorded on every
/// chapter turn and simply never read.
class _ResumeCard extends ConsumerWidget {
  const _ResumeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapter = ref.watch(lastChapterDetailProvider).valueOrNull;
    if (chapter == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.history, color: Palette.accent),
          title: const Text('Continue reading'),
          subtitle: Text(chapter.reference),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/bible/${chapter.bookId}/${chapter.number}'),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, {required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          '$title · $count books',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
}

class _BookGrid extends StatelessWidget {
  const _BookGrid({
    required this.books,
    required this.spokenAnchor,
    required this.keyFor,
  });

  final List<Book> books;
  final String? spokenAnchor;
  final GlobalKey Function(String bookId) keyFor;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: gridTileWidth(context, designed: 190),
        // 56 is the designed height; it only grows if the reader's text size
        // needs more than one line's worth of room inside it.
        mainAxisExtent: gridTileExtent(
          context,
          titleLines: 1,
          chrome: 24,
          minimum: 56,
        ),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final spoken = spokenAnchor == 'book:${book.id}';
        // The tile shows a name and a bare number, which is only legible
        // because the tiles are all the same shape and the number is always
        // small — read aloud, it came out as "Genesis 50" and sounded like a
        // reference to a chapter that does not exist. The label is for the ear;
        // the number stays as it looks.
        return Semantics(
          key: keyFor(book.id),
          button: true,
          label: '${book.name}, ${book.chapterCount} chapters',
          excludeSemantics: true,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: spoken ? Palette.accent.withValues(alpha: 0.16) : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Card(
              margin: EdgeInsets.zero,
              color: spoken ? Colors.transparent : null,
              elevation: spoken ? 0 : null,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.go('/bible/${book.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            Text(book.name, overflow: TextOverflow.ellipsis),
                      ),
                      // A name long enough to be cut still ends in an ellipsis,
                      // and without this the ellipsis touched the number:
                      // "2 Chronicles36" read as one word.
                      const SizedBox(width: 8),
                      Text(
                        '${book.chapterCount}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full-text search over the shipped WEB text, offline, via FTS5.
class _BibleSearchDelegate extends SearchDelegate<void> {
  _BibleSearchDelegate(this.ref);

  final WidgetRef ref;

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().length < 2) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Search all 66 books',
        body: 'Type at least two characters. The whole text is on the phone, '
            'so this works with no connection.',
      );
    }
    return FutureBuilder<List<VerseHit>>(
      future: ref.read(bibleProvider).search(query),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.error_outline,
            title: 'That search could not be run.',
            body: '${snapshot.error}',
          );
        }
        final hits = snapshot.data;
        if (hits == null) {
          return Loading('Searching for “$query”');
        }
        if (hits.isEmpty) {
          return EmptyState(
            icon: Icons.search_off,
            title: 'No verse contains “$query”.',
            body: 'Every word has to appear in the verse, so fewer words find '
                'more.',
          );
        }
        return ListView.builder(
          itemCount: hits.length,
          itemBuilder: (context, index) {
            final hit = hits[index];
            return ListTile(
              title: Text(hit.reference),
              subtitle: Text.rich(
                TextSpan(
                  children: [
                    for (final span in hit.spans)
                      TextSpan(
                        text: span.text,
                        style: span.isMatch
                            ? const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Palette.accent,
                              )
                            : null,
                      ),
                  ],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                close(context, null);
                context.go(
                  '/bible/${hit.verse.bookId}'
                  '/${hit.verse.chapterId.split('.').last}',
                );
              },
            );
          },
        );
      },
    );
  }
}
