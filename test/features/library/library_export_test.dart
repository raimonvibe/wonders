import 'package:bible_wonders/features/library/library_export.dart';
import 'package:bible_wonders/models/mark.dart';
import 'package:flutter_test/flutter_test.dart';

/// What leaves the phone when a reader exports their kept verses.
void main() {
  Mark markWith({
    String reference = 'Exodus 14:21',
    String preview = 'Moses stretched out his hand over the sea…',
    String? note,
  }) {
    return Mark(
      chapterId: 'EXO.14',
      verse: 21,
      bookId: 'EXO',
      reference: reference,
      preview: preview,
      colour: HighlightColour.amber,
      note: note,
      createdAt: DateTime(2026, 8, 2),
    );
  }

  test('carries the reference, the verse and the note', () {
    final text = LibraryExport.compose([
      markWith(note: 'Deliverance comes at the last moment.'),
    ]);

    expect(text, contains('Exodus 14:21'));
    expect(text, contains('Moses stretched out his hand over the sea'));
    expect(text, contains('Deliverance comes at the last moment.'));
  });

  test('credits the translation, because the verses are the bulk of it', () {
    final text = LibraryExport.compose([markWith()]);
    expect(text, contains('World English Bible'));
    expect(text, contains('public domain'));
  });

  test('says how many there are, and counts one correctly', () {
    expect(LibraryExport.compose([markWith()]), contains('1 verse.'));
    expect(
      LibraryExport.compose([markWith(), markWith(reference: 'Exodus 14:22')]),
      contains('2 verses.'),
    );
  });

  test('leaves out the note line entirely when there is none', () {
    expect(LibraryExport.compose([markWith()]), isNot(contains('Note:')));
    expect(
      LibraryExport.compose([markWith(note: '   ')]),
      isNot(contains('Note:')),
      reason: 'a note the reader left blank is not a note',
    );
  });

  test('an empty library says so rather than exporting a bare header', () {
    expect(LibraryExport.compose(const []), 'No verses kept yet.');
  });

  test('does not trail off into blank lines', () {
    final text = LibraryExport.compose([markWith(), markWith()]);
    expect(text, isNot(endsWith('\n')));
  });
}
