import 'package:flutter/material.dart';

/// The colours a verse can be marked in.
///
/// Both app themes are dark, so these are stated as translucent tints rather
/// than as inks: laid over pine or over ocean they read as the same four
/// colours, where four opaque swatches would fight one palette or the other.
/// Ids are stored, not indices, so reordering this list never repaints
/// somebody's Bible.
enum HighlightColour {
  amber('amber', 'Amber', Color(0xFFF4A261)),
  rose('rose', 'Rose', Color(0xFFE7737A)),
  sky('sky', 'Sky', Color(0xFF6BB8E8)),
  moss('moss', 'Moss', Color(0xFF86C08A));

  const HighlightColour(this.id, this.label, this.colour);

  final String id;
  final String label;
  final Color colour;

  /// The wash behind the verse.
  Color get fill => colour.withValues(alpha: 0.20);

  /// The rule down its left edge.
  Color get edge => colour;

  static HighlightColour parse(String? id) =>
      values.firstWhere((c) => c.id == id, orElse: () => HighlightColour.amber);
}

/// One verse the reader has kept.
///
/// A mark is a highlight and a bookmark at once: colouring a verse is what
/// saves it, and the library lists what has been coloured. Two separate
/// concepts would mean two gestures and two lists to explain, for a difference
/// nobody asked to make.
class Mark {
  const Mark({
    required this.chapterId,
    required this.verse,
    required this.bookId,
    required this.reference,
    required this.preview,
    required this.colour,
    required this.createdAt,
    this.id,
    this.note,
  });

  factory Mark.fromRow(Map<String, Object?> row) => Mark(
        id: row['id'] as int?,
        chapterId: row['chapter_id']! as String,
        verse: row['verse']! as int,
        bookId: row['book_id']! as String,
        reference: row['reference']! as String,
        preview: row['preview']! as String,
        colour: HighlightColour.parse(row['colour'] as String?),
        note: row['note'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at']! as int,
        ),
      );

  /// Null until the row has been written.
  final int? id;

  final String chapterId;
  final int verse;
  final String bookId;

  /// "Exodus 14:21". Kept on the row rather than looked up, because the library
  /// list would otherwise have to query the read-only scripture database once
  /// per entry just to draw a title.
  final String reference;

  /// The opening of the verse, for the same reason.
  final String preview;

  final HighlightColour colour;
  final String? note;
  final DateTime createdAt;

  bool get hasNote => note != null && note!.trim().isNotEmpty;

  /// How much of a verse the library shows before trailing off.
  static const previewLength = 140;

  static String previewOf(String text) => text.length <= previewLength
      ? text
      : '${text.substring(0, previewLength).trimRight()}…';

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'chapter_id': chapterId,
        'verse': verse,
        'book_id': bookId,
        'reference': reference,
        'preview': preview,
        'colour': colour.id,
        'note': hasNote ? note!.trim() : null,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  Mark copyWith({HighlightColour? colour, String? note, bool clearNote = false}) {
    return Mark(
      id: id,
      chapterId: chapterId,
      verse: verse,
      bookId: bookId,
      reference: reference,
      preview: preview,
      colour: colour ?? this.colour,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt,
    );
  }
}
