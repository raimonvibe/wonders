import 'wonder.dart' show Testament;

/// One of the 66 books, as stored in assets/bible.db.
class Book {
  const Book({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.testament,
    required this.sortOrder,
    required this.chapterCount,
  });

  factory Book.fromRow(Map<String, Object?> row) => Book(
        id: row['id']! as String,
        name: row['name']! as String,
        abbreviation: row['abbreviation']! as String,
        testament: Testament.parse(row['testament']! as String),
        sortOrder: row['sort_order']! as int,
        chapterCount: row['chapter_count']! as int,
      );

  /// Three-letter id, e.g. "EXO".
  final String id;
  final String name;
  final String abbreviation;
  final Testament testament;

  /// Canonical position, 1–66.
  final int sortOrder;
  final int chapterCount;
}

class Chapter {
  const Chapter({
    required this.id,
    required this.bookId,
    required this.number,
    required this.reference,
    required this.sortOrder,
    required this.verseCount,
  });

  factory Chapter.fromRow(Map<String, Object?> row) => Chapter(
        id: row['id']! as String,
        bookId: row['book_id']! as String,
        number: row['number']! as String,
        reference: row['reference']! as String,
        sortOrder: row['sort_order']! as int,
        verseCount: row['verse_count']! as int,
      );

  /// e.g. "EXO.14".
  final String id;
  final String bookId;

  /// Kept as a string to match the source data's keys.
  final String number;

  /// e.g. "Exodus 14".
  final String reference;
  final int sortOrder;
  final int verseCount;
}

/// A single verse. The build script split these out of the chapter blobs once,
/// so highlighting a range is a query rather than string surgery.
class Verse {
  const Verse({
    required this.chapterId,
    required this.bookId,
    required this.number,
    required this.text,
  });

  factory Verse.fromRow(Map<String, Object?> row) => Verse(
        chapterId: row['chapter_id']! as String,
        bookId: row['book_id']! as String,
        number: row['number']! as int,
        text: row['text']! as String,
      );

  final String chapterId;
  final String bookId;
  final int number;
  final String text;
}

/// One run of a search snippet, and whether it is what the reader searched for.
class SnippetSpan {
  const SnippetSpan(this.text, {this.isMatch = false});

  final String text;
  final bool isMatch;
}

/// A verse plus enough context to render it in a search result list.
class VerseHit {
  const VerseHit({
    required this.verse,
    required this.reference,
    required this.snippet,
  });

  /// The marks FTS5 is asked to wrap matches in. Defined here rather than in
  /// the query, because the code that writes them and the code that reads them
  /// back have to agree and there is no way to notice if they stop.
  static const matchOpen = '{';
  static const matchClose = '}';

  final Verse verse;

  /// e.g. "Exodus 14:21".
  final String reference;

  /// Raw FTS5 `snippet()` output, matches still wrapped in [matchOpen] and
  /// [matchClose]. Use [spans] to render it.
  final String snippet;

  /// The snippet split into plain and matched runs.
  ///
  /// Unbalanced marks are treated as ordinary text rather than swallowed. The
  /// WEB has no braces in it today, but a snippet that ends mid-match at the
  /// truncation ellipsis is ordinary, and losing the tail of a verse to it
  /// would be a silent bug.
  List<SnippetSpan> get spans {
    final spans = <SnippetSpan>[];
    var index = 0;

    while (index < snippet.length) {
      final open = snippet.indexOf(matchOpen, index);
      if (open < 0) break;

      final close = snippet.indexOf(matchClose, open + 1);
      if (close < 0) break;

      if (open > index) {
        spans.add(SnippetSpan(snippet.substring(index, open)));
      }
      final matched = snippet.substring(open + 1, close);
      if (matched.isNotEmpty) {
        spans.add(SnippetSpan(matched, isMatch: true));
      }
      index = close + 1;
    }

    if (index < snippet.length) {
      spans.add(SnippetSpan(snippet.substring(index)));
    }
    return spans;
  }
}
