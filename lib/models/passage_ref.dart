/// A scripture location a wonder card can send the reader to.
///
/// Mirrors `PassageRef` in ../../lib/passages.ts. The `label` is built on the
/// TypeScript side and carried over verbatim rather than reconstructed here,
/// so the app and the website never disagree about how a reference reads.
class PassageRef {
  const PassageRef({
    required this.bookId,
    required this.bookName,
    required this.chapterNumber,
    required this.firstVerse,
    required this.lastVerse,
    required this.label,
  });

  factory PassageRef.fromJson(Map<String, dynamic> json) {
    final verses = (json['verses'] as List<dynamic>).cast<num>();
    return PassageRef(
      bookId: json['bookId'] as String,
      bookName: json['bookName'] as String,
      chapterNumber: json['chapterNumber'] as String,
      firstVerse: verses[0].toInt(),
      lastVerse: verses[1].toInt(),
      label: json['label'] as String,
    );
  }

  final String bookId;
  final String bookName;

  /// Kept as a string because that is what the Bible data uses as a key.
  final String chapterNumber;

  /// Inclusive range to highlight in the reader.
  final int firstVerse;
  final int lastVerse;

  /// Human label, e.g. "Exodus 14:21–31".
  final String label;

  /// Chapter id used by the database, e.g. "EXO.14".
  String get chapterId => '$bookId.$chapterNumber';

  bool get isSingleVerse => firstVerse == lastVerse;

  bool highlights(int verseNumber) =>
      verseNumber >= firstVerse && verseNumber <= lastVerse;

  @override
  String toString() => label;
}
