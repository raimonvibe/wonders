import 'package:bible_wonders/features/wonders/wonder_card_body.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the card lands when the voice moves to a section.
///
/// Same contract as the passage reader's index-of-verse tests: the follow-along
/// scroll is driven by an index into the section list, and that mapping has to
/// stay in lockstep with the anchors [Speakables.card] emits.
void main() {
  // A full card, in the order WonderCardBody lays sections out when every
  // optional block is present and the Read-passage button is showing.
  const anchors = <String?>[
    'chips',
    'quote',
    null, // Read passage button
    'location',
    'details',
    'details:0',
    'details:1',
    'whatHappened',
    'hopeMeaning',
    'distinctive',
    'reflection',
    'parallels',
    null, // Read further
  ];

  test('lands on the section the voice is speaking', () {
    expect(
      WonderCardBody.indexOfSpokenSection(anchors, 'whatHappened'),
      7,
    );
    expect(WonderCardBody.indexOfSpokenSection(anchors, 'details:1'), 6);
    expect(WonderCardBody.indexOfSpokenSection(anchors, 'parallels'), 11);
  });

  test('title lands on the chips — the first thing on the card', () {
    // The title is spoken, but it lives in the app bar, not the scroll view.
    expect(WonderCardBody.indexOfSpokenSection(anchors, 'title'), 0);
  });

  test('unknown anchors do not produce a scroll index', () {
    expect(WonderCardBody.indexOfSpokenSection(anchors, 'nope'), isNull);
    expect(WonderCardBody.indexOfSpokenSection(anchors, null), isNull);
  });
}
