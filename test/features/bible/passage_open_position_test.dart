import 'package:bible_wonders/features/bible/passage_view.dart';
import 'package:bible_wonders/models/bible.dart';
import 'package:bible_wonders/models/passage_ref.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where a wonder's passage opens.
///
/// The regression this guards is the one that made the feature look absent:
/// the old code asked a lazy ListView to scroll to a GlobalKey that had never
/// been built, so a card citing Exodus 14:21 opened on verse 1 and silently did
/// nothing. Position is now an index, and an index is worth pinning — verse
/// numbers and list positions differ by one everywhere and by more wherever the
/// numbering has a gap.
void main() {
  List<Verse> chapterOf(Iterable<int> numbers) => [
        for (final n in numbers)
          Verse(
            chapterId: 'EXO.14',
            bookId: 'EXO',
            number: n,
            text: 'Verse $n.',
          ),
      ];

  PassageRef refFrom(int first, int last) => PassageRef(
        bookId: 'EXO',
        bookName: 'Exodus',
        chapterNumber: '14',
        firstVerse: first,
        lastVerse: last,
        label: 'Exodus 14:$first–$last',
      );

  test('opens on the first cited verse, not at its number', () {
    final verses = chapterOf(List.generate(31, (i) => i + 1));
    // Verse 21 is the twenty-first verse, so index 20. Using the number would
    // open on verse 22 — close enough to look intentional.
    expect(PassageView.indexOfFirstVerse(verses, refFrom(21, 31)), 20);
  });

  test('opens at the top when there is nothing cited', () {
    final verses = chapterOf(List.generate(31, (i) => i + 1));
    expect(PassageView.indexOfFirstVerse(verses, null), 0);
  });

  test('a citation of verse one opens at the top', () {
    final verses = chapterOf(List.generate(10, (i) => i + 1));
    expect(PassageView.indexOfFirstVerse(verses, refFrom(1, 4)), 0);
  });

  test('survives a gap in the numbering', () {
    // Some chapters in the shipped text skip a number. Counting positions
    // instead of matching them would put the reader in the wrong place.
    final verses = chapterOf([1, 2, 3, 6, 7, 8]);
    expect(PassageView.indexOfFirstVerse(verses, refFrom(6, 8)), 3);
  });

  test('falls back to the top rather than off the end', () {
    // A card citing a verse this chapter does not have must not produce a
    // negative index for the list to scroll to.
    final verses = chapterOf(List.generate(10, (i) => i + 1));
    expect(PassageView.indexOfFirstVerse(verses, refFrom(40, 44)), 0);
    expect(PassageView.indexOfFirstVerse(const [], refFrom(1, 2)), 0);
  });

  test('the last verse of a chapter is the last index', () {
    final verses = chapterOf(List.generate(31, (i) => i + 1));
    expect(PassageView.indexOfFirstVerse(verses, refFrom(31, 31)), 30);
  });
}
