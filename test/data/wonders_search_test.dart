import 'package:bible_wonders/data/wonders_repository.dart';
import 'package:bible_wonders/models/wonder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs against the real assets/wonders.json, because the bug these cover was
/// a mismatch between what the search looked at and what the catalog actually
/// contains. A hand-written fixture would have agreed with the old code.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WondersRepository repo;

  setUpAll(() async {
    repo = await WondersRepository.load();
  });

  group('search', () {
    test('finds a person named only in the prose', () {
      // The regression. No card is titled "Jesus" — searching for Him against
      // titles, references and places returned nothing at all, on a catalog
      // where half the wonders are His.
      final results = repo.search('jesus');
      expect(results, isNotEmpty);
      expect(
        results.every((w) => w.title.toLowerCase().contains('jesus')),
        isFalse,
        reason: 'prose matches are the whole point of this tier',
      );
    });

    test('ranks a title match above a prose-only match', () {
      final results = repo.search('sea');
      expect(results, isNotEmpty);

      final firstProseOnly = results.indexWhere(
        (w) => !w.title.toLowerCase().contains('sea'),
      );
      final lastTitled = results.lastIndexWhere(
        (w) => w.title.toLowerCase().contains('sea'),
      );

      if (firstProseOnly != -1 && lastTitled != -1) {
        expect(
          lastTitled,
          lessThan(firstProseOnly),
          reason: 'a card called "sea" must outrank one that mentions one',
        );
      }
    });

    test('matches a reference, punctuation and all', () {
      final results = repo.search('exodus 14');
      expect(results, isNotEmpty);

      // Normalising a reference turns "Exodus 7:14–25" into loose words, so
      // scattered terms alone would let chapter 7 answer a search for chapter
      // 14. The phrase tier is what keeps the right chapter in front.
      expect(results.first.passage.label, contains('Exodus 14'));
    });

    test('treats several words as AND, not OR', () {
      final one = repo.search('jesus').length;
      final two = repo.search('jesus leprosy').length;
      expect(two, lessThan(one));
      expect(two, greaterThan(0));
    });

    test('folds the two apostrophe styles together', () {
      // The WEB text uses ’ and the card titles use '. A reader typing either
      // has to find the same wonders.
      expect(repo.search("lot's").length, repo.search('lot’s').length);
    });

    test('an empty or whitespace query matches nothing', () {
      expect(repo.search(''), isEmpty);
      expect(repo.search('   '), isEmpty);
    });

    test('matchCount agrees with search', () {
      expect(repo.matchCount('jesus'), repo.search('jesus').length);
      expect(repo.matchCount(''), 0);
    });
  });

  group('the catalog the pickers offer', () {
    test('every theme has wonders behind it', () {
      // The theme picker offers all seven unconditionally, unlike the era
      // picker which filters to populated ones. That is only safe while this
      // holds.
      for (final theme in WonderTheme.values) {
        expect(
          repo.byTheme(theme),
          isNotEmpty,
          reason: 'the picker would offer $theme and then show an empty list',
        );
      }
    });

    test('every offered era has wonders behind it', () {
      for (final era in repo.populatedEras()) {
        expect(repo.byEra(era), isNotEmpty);
      }
    });

    test('the themes partition the catalog', () {
      final counted = WonderTheme.values.fold<int>(
        0,
        (sum, t) => sum + repo.byTheme(t).length,
      );
      expect(counted, repo.count);
    });
  });
}
