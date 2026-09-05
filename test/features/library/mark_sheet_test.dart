import 'package:bible_wonders/data/library_repository.dart';
import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/features/library/mark_sheet.dart';
import 'package:bible_wonders/models/bible.dart';
import 'package:bible_wonders/models/mark.dart';
import 'package:bible_wonders/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A library that lives in a list, so the sheet can be driven without sqflite.
class FakeLibrary implements LibraryRepository {
  final List<Mark> rows = [];
  int nextId = 1;

  @override
  Future<List<Mark>> all() async => rows;

  @override
  Future<Mark> save(Mark mark) async {
    rows.removeWhere((m) => m.chapterId == mark.chapterId && m.verse == mark.verse);
    final saved = Mark(
      id: mark.id ?? nextId++,
      chapterId: mark.chapterId,
      verse: mark.verse,
      bookId: mark.bookId,
      reference: mark.reference,
      preview: mark.preview,
      colour: mark.colour,
      note: mark.hasNote ? mark.note!.trim() : null,
      createdAt: mark.createdAt,
    );
    rows.insert(0, saved);
    return saved;
  }

  @override
  Future<void> remove(String chapterId, int verse) async {
    rows.removeWhere((m) => m.chapterId == chapterId && m.verse == verse);
  }

  @override
  Future<void> removeAll() async => rows.clear();

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _verse = Verse(
  chapterId: 'EXO.14',
  bookId: 'EXO',
  number: 21,
  text: 'Moses stretched out his hand over the sea, and Yahweh caused the sea '
      'to go back by a strong east wind all night, and made the sea dry land, '
      'and the waters were divided.',
);

void main() {
  late FakeLibrary library;
  late Prefs prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await Prefs.load();
    library = FakeLibrary();
  });

  Future<void> openSheet(WidgetTester tester, {List<Mark> initial = const []}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          libraryProvider.overrideWithValue(library),
          marksProvider.overrideWith((ref) => LibraryController(library, initial)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showMarkSheet(
                    context,
                    verse: _verse,
                    reference: 'Exodus 14:21',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a note written on an unmarked verse is saved', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Add a note'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Rescue at the last moment.');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(library.rows, hasLength(1));
    expect(library.rows.single.note, 'Rescue at the last moment.');
  });

  testWidgets('the sheet fits with the keyboard up on a small phone',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);

    await openSheet(tester);
    await tester.tap(find.text('Add a note'));
    await tester.pumpAndSettle();

    // The keyboard the note field just asked for.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'the sheet overflowed rather than scrolling',
    );

    // Reachable, and above the keyboard once reached — the two halves of
    // "the reader can finish writing a note on a small phone".
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('Save')).bottom,
      lessThanOrEqualTo(640 - 300),
      reason: 'the Save button sits under the keyboard',
    );
  });
}
