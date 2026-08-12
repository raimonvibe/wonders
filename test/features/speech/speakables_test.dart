import 'package:bible_wonders/data/reading_paths.dart';
import 'package:bible_wonders/data/wonders_repository.dart';
import 'package:bible_wonders/features/speech/speakables.dart';
import 'package:bible_wonders/features/speech/speech_controller.dart';
import 'package:bible_wonders/models/bible.dart';
import 'package:bible_wonders/models/passage_ref.dart';
import 'package:bible_wonders/models/wonder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// What read-aloud actually says.
///
/// Worth pinning because none of it is visible in a screenshot: a chunk that
/// silently loses the quote, or a chapter that reads its verse numbers out, is
/// only discoverable by listening to the whole thing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WondersRepository repo;

  setUpAll(() async {
    repo = await WondersRepository.load();
  });

  const chapter = Chapter(
    id: 'EXO.14',
    bookId: 'EXO',
    number: '14',
    reference: 'Exodus 14',
    sortOrder: 14,
    verseCount: 31,
  );

  List<Verse> versesFrom(int first, int last) => [
        for (var n = first; n <= last; n++)
          Verse(
            chapterId: 'EXO.14',
            bookId: 'EXO',
            number: n,
            text: 'Verse $n text.',
          ),
      ];

  String spokenText(dynamic speakable) =>
      (speakable.chunks as List).map((c) => c.text).join(' ');

  group('a wonder card', () {
    test('says the quote, and its reference after it', () {
      final wonder = testWonder();
      final card = Speakables.card(wonder, repo);
      final quote = card.chunks.firstWhere((c) => c.anchor == 'quote');

      expect(quote.text, startsWith(wonder.quote!));
      expect(
        quote.text.indexOf(wonder.quoteRef!),
        greaterThan(quote.text.indexOf(wonder.quote!)),
        reason: 'scripture should not be preceded by a string of numbers',
      );
    });

    test('reads every written field', () {
      final spoken = spokenText(Speakables.card(testWonder(), repo));
      for (final field in [
        'SECRET_WHAT_HAPPENED',
        'SECRET_HOPE_MEANING',
        'SECRET_REFLECTION',
        'A strong east wind blew all night.',
      ]) {
        expect(spoken, contains(field), reason: '$field never gets read');
      }
    });

    test('gives a heading and its prose separate chunks', () {
      // So a skip has somewhere to land, and so the heading does not run into
      // the paragraph behind it as one sentence.
      final card = Speakables.card(testWonder(), repo);
      final happened =
          card.chunks.where((c) => c.anchor == 'whatHappened').toList();
      expect(happened, hasLength(2));
      expect(happened.first.text, 'What happened.');
    });

    test('omits a field the card does not have', () {
      final wonder = testWonder(quote: null, quoteRef: null, location: null);
      final card = Speakables.card(wonder, repo);
      expect(card.chunks.where((c) => c.anchor == 'quote'), isEmpty);
      expect(card.chunks.where((c) => c.anchor == 'location'), isEmpty);
    });

    test('every card in the real catalog has something to say', () {
      for (final wonder in repo.wonders) {
        final card = Speakables.card(wonder, repo);
        expect(card.isEmpty, isFalse, reason: '${wonder.id} reads as silence');
        expect(
          card.chunks.every((c) => c.text.trim().isNotEmpty),
          isTrue,
          reason: '${wonder.id} has an empty utterance in it',
        );
      }
    });
  });

  group('a chapter', () {
    test('is one chunk per verse, and does not speak the numbers', () {
      final speakable = Speakables.chapter(chapter, versesFrom(1, 31));

      // The reference chunk leads, then the verses.
      expect(speakable.length, 32);
      expect(speakable.chunks.first.text, 'Exodus 14');

      final verse21 = speakable.chunks[21];
      expect(verse21.text, 'Verse 21 text.');
      expect(
        verse21.text,
        isNot(startsWith('21')),
        reason: 'the number is on screen; spoken it breaks the sentence',
      );
      expect(verse21.anchor, Speakables.verseAnchor('EXO.14', 21));
    });

    test('starts on the verse the card cites, not at verse one', () {
      final speakable = Speakables.chapter(chapter, versesFrom(1, 31));
      const ref = PassageRef(
        bookId: 'EXO',
        bookName: 'Exodus',
        chapterNumber: '14',
        firstVerse: 21,
        lastVerse: 31,
        label: 'Exodus 14:21–31',
      );

      final start = Speakables.startOf(speakable, ref);
      expect(speakable.chunks[start].anchor, 'verse:EXO.14:21');
    });

    test('falls back to the beginning when the verse is not there', () {
      // A card citing a verse this chapter does not have must not start the
      // reading at a negative index.
      final speakable = Speakables.chapter(chapter, versesFrom(1, 10));
      const ref = PassageRef(
        bookId: 'EXO',
        bookName: 'Exodus',
        chapterNumber: '14',
        firstVerse: 21,
        lastVerse: 31,
        label: 'Exodus 14:21–31',
      );
      expect(Speakables.startOf(speakable, ref), 0);
      expect(Speakables.startOf(speakable, null), 0);
    });
  });

  group('reach', () {
    final wonder = testWonder();

    test('card asks nothing of the database', () {
      final speakable = Speakables.forReach(
        SpeechReach.card,
        wonder: wonder,
        repo: repo,
      );
      expect(speakable, isNotNull);
      expect(speakable!.id, Speakables.cardId(wonder));
    });

    test('passage without verses is refused rather than faked', () {
      expect(
        Speakables.forReach(
          SpeechReach.passage,
          wonder: wonder,
          repo: repo,
        ),
        isNull,
      );
    });

    test('both walks the card and then the passage', () {
      final speakable = Speakables.forReach(
        SpeechReach.both,
        wonder: wonder,
        repo: repo,
        chapter: chapter,
        verses: versesFrom(1, 31),
      )!;

      final text = spokenText(speakable);
      expect(text, contains(wonder.quote!));
      expect(text, contains('Verse 21 text.'));

      // The chapter's own title chunk is dropped: "Now the passage." already
      // introduces it, and the reference would be said twice in a row.
      expect(
        'Exodus 14'.allMatches(text).length,
        lessThan(3),
        reason: 'the reference should not be announced twice over',
      );
    });

    test('both degrades to the card when the chapter is missing', () {
      // A database miss the reader cannot see should not mean silence.
      final speakable = Speakables.forReach(
        SpeechReach.both,
        wonder: wonder,
        repo: repo,
      );
      expect(speakable, isNotNull);
      expect(speakable!.id, Speakables.cardId(wonder));
    });
  });

  group('the reach setting', () {
    test('keeps the website spellings, so the two stores agree', () {
      // Prefs writes these into the key useTourNarration.ts reads.
      expect(SpeechReach.card.id, 'tour');
      expect(SpeechReach.passage.id, 'passage');
      expect(SpeechReach.both.id, 'both');
    });

    test('an unknown or missing value falls back to the card', () {
      expect(SpeechReach.parse(null), SpeechReach.card);
      expect(SpeechReach.parse('nonsense'), SpeechReach.card);
      expect(SpeechReach.parse('both'), SpeechReach.both);
    });
  });

  group('wonders home list', () {
    test('era path without a filter reads the choices in one sentence', () {
      final speakable = Speakables.wondersList(
        catalogCount: 10,
        path: const PathState(path: ReadingPath.era),
        wonders: const [],
        pickerOptions: const ['Torah', 'The Gospels'],
      );
      final spoken = spokenText(speakable);
      expect(
        spoken,
        contains('Choose a book or era to continue: Torah and The Gospels.'),
      );
      expect(spoken, isNot(contains('Nothing on this path matches.')));
      // One picker chunk — not one utterance per short label.
      expect(speakable.chunks.where((c) => c.anchor == 'picker'), hasLength(1));
    });

    test('theme path without a filter asks to choose, not empty', () {
      final spoken = spokenText(
        Speakables.wondersList(
          catalogCount: 10,
          path: const PathState(path: ReadingPath.theme),
          wonders: const [],
          pickerOptions: const ['Rescue'],
        ),
      );
      expect(spoken, contains('Choose a theme to continue: Rescue.'));
      expect(spoken, isNot(contains('Nothing on this path matches.')));
    });

    test('filtered path with no matches says empty', () {
      final spoken = spokenText(
        Speakables.wondersList(
          catalogCount: 10,
          path: const PathState(
            path: ReadingPath.theme,
            theme: WonderTheme.rescue,
          ),
          wonders: const [],
        ),
      );
      expect(spoken, contains('Nothing on this path matches.'));
    });

    test('lists wonders in groups, not one tiny line each', () {
      final wonders = [
        testWonder(id: 'a', title: 'Alpha'),
        testWonder(id: 'b', title: 'Beta'),
        testWonder(id: 'c', title: 'Gamma'),
        testWonder(id: 'd', title: 'Delta'),
      ];
      final speakable = Speakables.wondersList(
        catalogCount: 10,
        path: const PathState(path: ReadingPath.catalog),
        wonders: wonders,
      );
      final wonderChunks =
          speakable.chunks.where((c) => c.anchor?.startsWith('wonder:') ?? false);
      // 4 wonders → 2 groups of up to 3, not 4 (+ separate count).
      expect(wonderChunks.length, 2);
      expect(speakable.chunks.firstWhere((c) => c.anchor?.startsWith('wonder:') ?? false).text,
          startsWith('4 wonders.'));
    });
  });
}
