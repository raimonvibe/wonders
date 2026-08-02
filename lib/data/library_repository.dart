import '../models/mark.dart';
import 'library_database.dart';

/// Every read and write against the reader's own marks.
///
/// Narrow on purpose, like BibleRepository. The one difference is that this
/// database is writable, which is the whole reason it is a separate file.
class LibraryRepository {
  LibraryRepository(this._database);

  final LibraryDatabase _database;

  static Future<LibraryRepository> open() async =>
      LibraryRepository(await LibraryDatabase.open());

  /// Every mark, newest first.
  ///
  /// Loaded once into [LibraryController] and kept in memory afterwards. Even
  /// a reader who marks a verse a day for a decade has fewer rows than the
  /// catalog has wonders, and holding them makes the reader's highlights a
  /// synchronous lookup rather than a query per verse per frame.
  Future<List<Mark>> all() async {
    final rows = await _database.db.query('marks', orderBy: 'created_at DESC');
    return rows.map(Mark.fromRow).toList();
  }

  /// Insert or replace the mark on this verse. The unique index on
  /// (chapter_id, verse) is declared ON CONFLICT REPLACE, so re-colouring a
  /// verse updates it rather than accumulating rows.
  Future<Mark> save(Mark mark) async {
    final id = await _database.db.insert('marks', mark.toRow());
    return Mark(
      id: id,
      chapterId: mark.chapterId,
      verse: mark.verse,
      bookId: mark.bookId,
      reference: mark.reference,
      preview: mark.preview,
      colour: mark.colour,
      note: mark.hasNote ? mark.note!.trim() : null,
      createdAt: mark.createdAt,
    );
  }

  Future<void> remove(String chapterId, int verse) async {
    await _database.db.delete(
      'marks',
      where: 'chapter_id = ? AND verse = ?',
      whereArgs: [chapterId, verse],
    );
  }

  Future<void> removeAll() async => _database.db.delete('marks');
}
