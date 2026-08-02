import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The reader's own marks, in their own database.
///
/// Deliberately not a table in bible.db. That file is opened read-only on
/// purpose and is replaced wholesale whenever the asset is rebuilt — a verse
/// somebody highlighted in 2026 would be thrown away by a text correction in
/// 2027. Scripture ships with the app; what the reader makes of it is theirs.
class LibraryDatabase {
  LibraryDatabase._(this.db);

  static const _fileName = 'library.db';
  static const _schemaVersion = 1;

  final Database db;

  static LibraryDatabase? _instance;

  static Future<LibraryDatabase> open() async {
    final existing = _instance;
    if (existing != null) return existing;

    final path = p.join(await getDatabasesPath(), _fileName);
    final db = await openDatabase(
      path,
      version: _schemaVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE marks (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            chapter_id  TEXT    NOT NULL,
            verse       INTEGER NOT NULL,
            book_id     TEXT    NOT NULL,
            reference   TEXT    NOT NULL,
            preview     TEXT    NOT NULL,
            colour      TEXT    NOT NULL,
            note        TEXT,
            created_at  INTEGER NOT NULL,
            UNIQUE (chapter_id, verse) ON CONFLICT REPLACE
          )
        ''');

        // The list is read newest-first and the reader is read by chapter.
        await db.execute(
          'CREATE INDEX marks_by_chapter ON marks (chapter_id)',
        );
        await db.execute(
          'CREATE INDEX marks_by_date ON marks (created_at DESC)',
        );
      },
    );

    return _instance = LibraryDatabase._(db);
  }

  Future<void> close() async {
    await db.close();
    _instance = null;
  }
}
