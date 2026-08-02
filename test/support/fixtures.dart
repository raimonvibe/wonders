import 'package:bible_wonders/models/passage_ref.dart';
import 'package:bible_wonders/models/wonder.dart';

/// A wonder with every prose field filled in.
///
/// The prose matters here even though most tests do not read it: ShareCard's
/// whole contract is that it leaves this text off the image, and a fixture
/// with empty prose would pass that test for the wrong reason.
Wonder testWonder({
  String id = 'red-sea',
  String title = 'The Parting of the Red Sea',
  Testament testament = Testament.old,
  String? quote =
      'Moses stretched out his hand over the sea, and Yahweh caused the sea '
          'to go back by a strong east wind all night, and made the sea dry '
          'land, and the waters were divided.',
  String? quoteRef = 'Exodus 14:21',
  String? location = 'The Red Sea',
}) {
  return Wonder(
    id: id,
    title: title,
    testament: testament,
    passage: const PassageRef(
      bookId: 'EXO',
      bookName: 'Exodus',
      chapterNumber: '14',
      firstVerse: 21,
      lastVerse: 31,
      label: 'Exodus 14:21–31',
    ),
    theme: WonderTheme.rescue,
    era: WonderEra.torah,
    authored: true,
    familiarityRank: 1,
    location: location,
    quote: quote,
    quoteRef: quoteRef,
    details: const ['A strong east wind blew all night.'],
    whatHappened: 'SECRET_WHAT_HAPPENED — our prose, never on the image.',
    hopeMeaning: 'SECRET_HOPE_MEANING — our prose, never on the image.',
    reflectionQuestion: 'SECRET_REFLECTION — our prose, never on the image.',
  );
}
