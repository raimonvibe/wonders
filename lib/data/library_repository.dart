import 'package:sqflite/sqflite.dart';

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

  /// Insert or replace the mark on this verse.
  ///
  /// The REPLACE has to be asked for here and not left to the schema. The
  /// table declares ON CONFLICT REPLACE on the unique index over
  /// (chapter_id, verse), but a mark that already exists carries its `id`,
  /// and an `id` in the row is a second constraint — the rowid primary key,
  /// whose conflict clause is the default ABORT. SQLite reached that one
  /// first and threw `UNIQUE constraint failed: marks.id`, so every write to
  /// a verse that was already marked failed: adding a note to it, and
  /// re-colouring it. Only the first mark on a verse, which carries no id,
  /// ever got through.
  ///
  /// ConflictAlgorithm.replace covers both constraints, and keeping the id in
  /// the row is what lets the mark keep its identity across the replace.
  Future<Mark> save(Mark mark) async {
    final id = await _database.db.insert(
      'marks',
      mark.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
