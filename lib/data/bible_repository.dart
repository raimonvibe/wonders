import '../models/bible.dart';
import '../models/passage_ref.dart';
import '../models/wonder.dart' show Testament;
import 'bible_database.dart';

/// Every read against the shipped scripture goes through here.
///
/// The queries are deliberately narrow — a chapter at a time, a range at a
/// time. Nothing loads the whole Bible into memory, which is the entire reason
/// the text was moved out of JSON and into SQLite.
class BibleRepository {
  BibleRepository(this._database);

  final BibleDatabase _database;

  static Future<BibleRepository> open() async =>
      BibleRepository(await BibleDatabase.open());

  Future<List<Book>> books({Testament? testament}) async {
    final rows = await _database.db.query(
      'books',
      where: testament == null ? null : 'testament = ?',
      whereArgs: testament == null ? null : [testament.id],
      orderBy: 'sort_order',
    );
    return rows.map(Book.fromRow).toList();
  }

  Future<Book?> book(String bookId) async {
    final rows = await _database.db.query(
      'books',
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    return rows.isEmpty ? null : Book.fromRow(rows.first);
  }

  Future<List<Chapter>> chapters(String bookId) async {
    final rows = await _database.db.query(
      'chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'sort_order',
    );
    return rows.map(Chapter.fromRow).toList();
  }

  Future<Chapter?> chapter(String chapterId) async {
    final rows = await _database.db.query(
      'chapters',
      where: 'id = ?',
      whereArgs: [chapterId],
      limit: 1,
    );
    return rows.isEmpty ? null : Chapter.fromRow(rows.first);
  }

  Future<List<Verse>> versesIn(String chapterId) async {
    final rows = await _database.db.query(
      'verses',
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
      orderBy: 'number',
    );
    return rows.map(Verse.fromRow).toList();
  }

  /// The verses a wonder's reference names — what the share card quotes from
  /// and what the reader highlights.
  Future<List<Verse>> versesFor(PassageRef ref) async {
    final rows = await _database.db.query(
      'verses',
      where: 'chapter_id = ? AND number BETWEEN ? AND ?',
      whereArgs: [ref.chapterId, ref.firstVerse, ref.lastVerse],
      orderBy: 'number',
    );
    return rows.map(Verse.fromRow).toList();
  }

  /// Chapter-to-chapter navigation that crosses book boundaries, so swiping
  /// past the end of Genesis 50 lands in Exodus 1.
  Future<Chapter?> adjacentChapter(Chapter from, {required int offset}) async {
    final rows = await _database.db.rawQuery(
      '''
      SELECT c.* FROM chapters c
      JOIN books b ON b.id = c.book_id
      ORDER BY b.sort_order, c.sort_order
      LIMIT 1 OFFSET (
        SELECT count(*) FROM chapters c2
        JOIN books b2 ON b2.id = c2.book_id
        WHERE (b2.sort_order, c2.sort_order) <
              ((SELECT sort_order FROM books WHERE id = ?), ?)
      ) + ?
      ''',
      [from.bookId, from.sortOrder, offset],
    );
    return rows.isEmpty ? null : Chapter.fromRow(rows.first);
  }

  /// Full-text search over every verse, via the FTS5 index the build script
  /// created. Replaces the website's AdvancedSearch, and works offline.
  Future<List<VerseHit>> search(String query, {int limit = 100}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final rows = await _database.db.rawQuery(
      '''
      SELECT v.chapter_id, v.book_id, v.number, v.text,
             b.name AS book_name,
             c.number AS chapter_number,
             snippet(
               verses_fts, 0,
               '${VerseHit.matchOpen}', '${VerseHit.matchClose}',
               '…', 12
             ) AS snippet
      FROM verses_fts f
      JOIN verses v   ON v.id = f.rowid
      JOIN chapters c ON c.id = v.chapter_id
      JOIN books b    ON b.id = v.book_id
      WHERE verses_fts MATCH ?
      ORDER BY bm25(verses_fts), b.sort_order, c.sort_order, v.number
      LIMIT ?
      ''',
      [_toMatchQuery(trimmed), limit],
    );

    return rows.map((row) {
      return VerseHit(
        verse: Verse.fromRow(row),
        reference: '${row['book_name']} ${row['chapter_number']}:'
            '${row['number']}',
        snippet: row['snippet']! as String,
      );
    }).toList();
  }

  /// FTS5 treats a bare apostrophe or hyphen as syntax, and the WEB text is
  /// full of both. Quoting each token keeps a search for "Yahweh's" from
  /// throwing rather than matching.
  static String _toMatchQuery(String input) {
    final tokens = input
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '')}"');
    return tokens.join(' AND ');
  }
}
