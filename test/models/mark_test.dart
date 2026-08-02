import 'package:bible_wonders/models/mark.dart';
import 'package:flutter_test/flutter_test.dart';

/// A kept verse, as it goes into the database and comes back out.
///
/// Marks are the one thing in this app the reader creates and cannot get again
/// from the asset bundle, so the round trip is worth pinning.
void main() {
  Mark markWith({String? note, HighlightColour colour = HighlightColour.amber}) {
    return Mark(
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

  group('colours', () {
    test('are stored by id, so the list can be reordered safely', () {
      // Storing an index would repaint every reader's Bible the day a colour
      // is inserted in the middle of the enum.
      for (final colour in HighlightColour.values) {
        expect(HighlightColour.parse(colour.id), colour);
      }
    });

    test('fall back rather than throwing on an unknown id', () {
      expect(HighlightColour.parse('chartreuse'), HighlightColour.amber);
      expect(HighlightColour.parse(null), HighlightColour.amber);
    });

    test('are translucent, so both dark palettes show through', () {
      for (final colour in HighlightColour.values) {
        expect(colour.fill.a, lessThan(1.0));
        expect(colour.edge.a, 1.0);
      }
    });
  });

  group('the row round trip', () {
    test('survives intact', () {
      final original = markWith(note: 'Deliverance comes at the last moment.');
      final restored = Mark.fromRow({...original.toRow(), 'id': 7});

      expect(restored.id, 7);
      expect(restored.chapterId, original.chapterId);
      expect(restored.verse, original.verse);
      expect(restored.bookId, original.bookId);
      expect(restored.reference, original.reference);
      expect(restored.preview, original.preview);
      expect(restored.colour, original.colour);
      expect(restored.note, original.note);
      expect(restored.createdAt, original.createdAt);
    });

    test('omits the id before the row exists', () {
      // Passing a null id to sqflite's insert would write a NULL primary key
      // rather than letting AUTOINCREMENT assign one.
      expect(markWith().toRow().containsKey('id'), isFalse);
    });

    test('stores a blank note as no note at all', () {
      // Otherwise the reader gets a note icon in the margin for a note they
      // opened, thought better of, and left empty.
      expect(markWith(note: '   ').toRow()['note'], isNull);
      expect(markWith(note: '').hasNote, isFalse);
      expect(markWith(note: null).hasNote, isFalse);
      expect(markWith(note: 'something').hasNote, isTrue);
    });

    test('trims a note before storing it', () {
      expect(markWith(note: '  kept  ').toRow()['note'], 'kept');
    });
  });

  group('the preview', () {
    test('keeps a short verse whole', () {
      const short = 'Jesus wept.';
      expect(Mark.previewOf(short), short);
    });

    test('trails off rather than running on', () {
      final long = 'a' * 400;
      final preview = Mark.previewOf(long);
      expect(preview.length, Mark.previewLength + 1); // the ellipsis
      expect(preview, endsWith('…'));
    });

    test('does not leave a space before the ellipsis', () {
      final text = '${'a' * (Mark.previewLength - 1)} trailing words here';
      expect(Mark.previewOf(text), isNot(contains(' …')));
    });
  });

  test('recolouring keeps the note and the date', () {
    final original = markWith(note: 'kept');
    final recoloured = original.copyWith(colour: HighlightColour.sky);

    expect(recoloured.colour, HighlightColour.sky);
    expect(recoloured.note, 'kept');
    expect(recoloured.createdAt, original.createdAt);
  });
}
