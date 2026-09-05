import 'package:bible_wonders/data/library_database.dart';
import 'package:bible_wonders/data/library_repository.dart';
import 'package:bible_wonders/models/mark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The reader's marks against a real SQLite, not a stand-in.
///
/// This file exists because a fake repository cannot fail the way the real one
/// did. Saving a note went through the widget, through the controller, and was
/// handed to a stub that simply kept it — while on a phone the same write threw
/// `UNIQUE constraint failed: marks.id` and nothing was ever stored. The
/// contract that broke is a SQL one, so it has to be tested in SQL.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late LibraryRepository repo;

  Mark markWith({
    HighlightColour colour = HighlightColour.amber,
    String? note,
    int? id,
  }) {
    return Mark(
      id: id,
      chapterId: 'EXO.14',
      verse: 21,
      bookId: 'EXO',
      reference: 'Exodus 14:21',
      preview: 'Moses stretched out his hand over the sea…',
      colour: colour,
      note: note,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );
  }

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await LibraryDatabase.defineSchema(db);
    repo = LibraryRepository(LibraryDatabase.over(db));
  });

  tearDown(() async => db.close());

  test('a note can be added to a verse that is already marked', () async {
    // The exact sequence that failed on a phone: colour a verse, then write a
    // note on it. The second save carries the id the first one returned, and
    // that id is a primary-key conflict the schema does not resolve.
    final first = await repo.save(markWith());
    expect(first.id, isNotNull);

    final noted = await repo.save(
      markWith(id: first.id, note: 'Deliverance at the last moment.'),
    );

    expect(noted.note, 'Deliverance at the last moment.');
    expect(await repo.all(), hasLength(1));
    expect((await repo.all()).single.note, 'Deliverance at the last moment.');
  });

  test('a marked verse can be re-coloured, note and all', () async {
    final first = await repo.save(markWith(note: 'Kept.'));
    await repo.save(
      markWith(id: first.id, colour: HighlightColour.sky, note: 'Kept.'),
    );

    final all = await repo.all();
    expect(all, hasLength(1), reason: 're-colouring must not add a row');
    expect(all.single.colour, HighlightColour.sky);
    expect(all.single.note, 'Kept.');
  });

  test('re-saving keeps one row per verse, whatever the id', () async {
    await repo.save(markWith());
    await repo.save(markWith(note: 'no id, straight through the unique index'));
    expect(await repo.all(), hasLength(1));
  });

  test('a blank note is stored as no note at all', () async {
    final saved = await repo.save(markWith(note: '   '));
    expect(saved.hasNote, isFalse);
    expect((await repo.all()).single.note, isNull);
  });

  test('removing a mark leaves the verse unmarked', () async {
    await repo.save(markWith(note: 'gone in a moment'));
    await repo.remove('EXO.14', 21);
    expect(await repo.all(), isEmpty);
  });
}
