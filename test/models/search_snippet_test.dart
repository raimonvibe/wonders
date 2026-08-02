import 'package:bible_wonders/models/bible.dart';
import 'package:flutter_test/flutter_test.dart';

/// Splitting FTS5's snippet output into the runs the result list renders bold.
///
/// Pinned because the failure is quiet: a parser that loses the tail of a
/// snippet still produces a plausible-looking search result, just one missing
/// the half of the verse that came after the last match.
void main() {
  VerseHit hitWith(String snippet) => VerseHit(
        verse: const Verse(
          chapterId: 'EXO.14',
          bookId: 'EXO',
          number: 21,
          text: 'unused',
        ),
        reference: 'Exodus 14:21',
        snippet: snippet,
      );

  List<String> textsOf(VerseHit hit) => hit.spans.map((s) => s.text).toList();
  List<bool> matchesOf(VerseHit hit) =>
      hit.spans.map((s) => s.isMatch).toList();

  test('marks the matched run and leaves the rest alone', () {
    final hit = hitWith('Moses stretched out his {hand} over the sea');
    expect(textsOf(hit), [
      'Moses stretched out his ',
      'hand',
      ' over the sea',
    ]);
    expect(matchesOf(hit), [false, true, false]);
  });

  test('handles several matches in one snippet', () {
    final hit = hitWith('the {sea} was divided, and the {sea} went back');
    expect(matchesOf(hit), [false, true, false, true, false]);
    expect(
      hit.spans.where((s) => s.isMatch).map((s) => s.text),
      ['sea', 'sea'],
    );
  });

  test('keeps a match at either end', () {
    expect(textsOf(hitWith('{Yahweh} caused it')), ['Yahweh', ' caused it']);
    expect(textsOf(hitWith('caused by {Yahweh}')), ['caused by ', 'Yahweh']);
  });

  test('a snippet with no match is one plain run', () {
    final hit = hitWith('nothing matched here');
    expect(textsOf(hit), ['nothing matched here']);
    expect(matchesOf(hit), [false]);
  });

  test('an empty snippet produces nothing to render', () {
    expect(hitWith('').spans, isEmpty);
  });

  test('an unclosed mark is text, not a swallowed tail', () {
    // The regression this guards: returning early on a stray brace dropped
    // everything after it, so a truncated snippet lost the rest of the verse.
    final hit = hitWith('the sea {went back and the waters');
    expect(textsOf(hit).join(), 'the sea {went back and the waters');
    expect(matchesOf(hit), everyElement(isFalse));
  });

  test('keeps the ellipsis FTS5 uses for truncation', () {
    final hit = hitWith('…caused the {sea} to go back…');
    expect(textsOf(hit).join(), '…caused the sea to go back…');
  });
}
