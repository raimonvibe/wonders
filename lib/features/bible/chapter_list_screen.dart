import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/bible.dart';
import '../../providers.dart';
import '../../theme/metrics.dart';
import '../../theme/states.dart';
import '../speech/listen_button.dart';
import '../speech/speakables.dart';

/// The chapters of one book, as a grid of numbers.
class ChapterListScreen extends ConsumerStatefulWidget {
  const ChapterListScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends ConsumerState<ChapterListScreen> {
  late final Future<(Book?, List<Chapter>)> _data = _load();

  Future<(Book?, List<Chapter>)> _load() async {
    final repo = ref.read(bibleProvider);
    return (await repo.book(widget.bookId), await repo.chapters(widget.bookId));
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themeProvider);

    return FutureBuilder<(Book?, List<Chapter>)>(
      future: _data,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final book = data?.$1;
        final chapters = data?.$2 ?? const <Chapter>[];

        // Reading a book is what decides the app's mood, so set the palette as
        // soon as we know which testament this book is in.
        if (book != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(themeProvider.notifier).followTestament(book.testament);
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(book?.name ?? ''),
            actions: [
              if (book != null)
                ListenButton(
                  sourceId: Speakables.chaptersId(book.id),
                  source: () async => Speakables.chapterList(book, chapters),
                  tooltip: 'Say what is here',
                ),
            ],
          ),
          body: DecoratedBox(
            decoration: BoxDecoration(gradient: palette.pageGradient),
            child: data == null
                ? const Loading('Opening the book')
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 76,
                      mainAxisExtent: gridTileExtent(
                        context,
                        titleLines: 1,
                        chrome: 24,
                        minimum: 56,
                      ),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      // A grid of bare numerals is the right thing to look at
                      // and the wrong thing to listen to: TalkBack read this
                      // screen as "one, two, three" with no clue what was being
                      // counted. Sighted readers keep the numerals.
                      return Semantics(
                        button: true,
                        label: '${book?.name ?? 'Chapter'} ${chapter.number}',
                        excludeSemantics: true,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => context.go(
                              '/bible/${widget.bookId}/${chapter.number}',
                            ),
                            child: Center(child: Text(chapter.number)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
