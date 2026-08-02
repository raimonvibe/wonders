/// What read-aloud actually says, and what it is saying it about.
///
/// The website walks the DOM to find its chunks (../../lib/readAloud.ts). There
/// is no DOM here, so a screen builds its own queue instead — see
/// speakables.dart, which is the one place that knows how a wonder card or a
/// chapter turns into speech. Everything else in features/speech/ deals only in
/// the two types below.
library;

/// One utterance. The engine is handed exactly this string.
///
/// Chunks are deliberately small — a verse, a paragraph, a heading — for three
/// reasons: skipping has somewhere to land, the highlight can follow along, and
/// a stop takes effect at the end of a sentence rather than a chapter.
class SpeechChunk {
  const SpeechChunk(this.text, {this.anchor, this.label});

  final String text;

  /// Ties this chunk back to what is on screen, so a view can mark the line
  /// being spoken. `verse:EXO.14:21` for scripture, `whatHappened` and friends
  /// for a card. Null when nothing on screen corresponds to it.
  final String? anchor;

  /// What the mini player shows while this chunk is speaking, e.g.
  /// "Exodus 14:21". Falls back to the source's title when null.
  final String? label;
}

/// A queue of chunks, and where it came from.
class Speakable {
  const Speakable({
    required this.id,
    required this.title,
    required this.chunks,
  });

  /// Identifies the *content*, not the instance: rebuilding a screen must
  /// produce the same id, because that is how the Listen button knows whether
  /// what is playing is its own material or somebody else's.
  final String id;

  /// Shown in the mini player — "Crossing the Red Sea", "Exodus 14".
  final String title;

  final List<SpeechChunk> chunks;

  bool get isEmpty => chunks.isEmpty;
  int get length => chunks.length;

  /// The first chunk carrying [anchor], or -1. Used to start a chapter at the
  /// verse a wonder cites rather than at verse 1.
  int indexOfAnchor(String anchor) =>
      chunks.indexWhere((chunk) => chunk.anchor == anchor);
}
