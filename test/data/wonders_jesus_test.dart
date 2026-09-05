import 'package:bible_wonders/data/reading_paths.dart';
import 'package:bible_wonders/data/wonders_repository.dart';
import 'package:bible_wonders/models/wonder.dart';
import 'package:flutter_test/flutter_test.dart';

/// The "Wonders of Jesus" tile, against the real assets/wonders.json.
///
/// Two things need pinning. One is the derivation: no wonder carries a field
/// saying it is His, so the collection reads the Gospel eras instead, and that
/// only stays true while the catalog keeps putting the apostles' wonders in
/// `acts`. The other is that adding the tile did not cost the seven kinds
/// anything — the whole reason it is a collection and not an eighth theme.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WondersRepository repo;
  late List<Wonder> jesus;

  setUpAll(() async {
    repo = await WondersRepository.load();
    jesus = repo.byCollection(WonderCollection.jesus);
  });

  group('what the collection holds', () {
    test('is every Gospel account and nothing else', () {
      expect(jesus.map((w) => w.id), repo.wonders.where((w) => w.era.isGospel).map((w) => w.id));
      expect(
        jesus.every((w) => w.testament == Testament.aNew),
        isTrue,
      );
      expect(
        jesus.any((w) => w.era == WonderEra.acts),
        isFalse,
        reason: 'Acts is the apostles working wonders, not Jesus',
      );
    });

    test('is 72 accounts of 37 events', () {
      // Stated as a number on purpose. The collection is derived rather than
      // tagged, so a Gospel entry that is *not* His — an angel at the tomb,
      // Zechariah struck mute — would join it silently. Failing here is the
      // prompt to go and look before changing the count.
      expect(jesus, hasLength(72));

      final events = <String>{
        for (final w in jesus) w.parallelGroupId ?? w.id,
      };
      expect(events, hasLength(37));
    });

    test('covers the Gospels the catalog knows', () {
      for (final era in [
        WonderEra.matthew,
        WonderEra.mark,
        WonderEra.luke,
        WonderEra.john,
      ]) {
        expect(jesus.where((w) => w.era == era), isNotEmpty);
      }
    });

    test('holds the ones a reader would go looking for', () {
      // A count alone would pass on any 72 cards.
      for (final id in ['cana', 'lazarus', 'feeding-5000-mrk', 'resurrection-jhn']) {
        expect(
          jesus.map((w) => w.id),
          contains(id),
          reason: '$id is one of His and belongs in the collection',
        );
      }
    });
  });

  group('what it costs the seven kinds', () {
    test('nothing — they still partition the catalog', () {
      final counted = WonderTheme.values.fold<int>(
        0,
        (sum, t) => sum + repo.byTheme(t).length,
      );
      expect(counted, repo.count);
    });

    test('every wonder of Jesus is still under its own kind', () {
      for (final w in jesus) {
        expect(
          repo.byTheme(w.theme).map((x) => x.id),
          contains(w.id),
          reason: 'the collection is a second axis, not a re-tagging',
        );
      }
    });
  });

  group('the picker tiles', () {
    test('offer the collections and then the seven kinds', () {
      expect(
        ThemeFilter.tiles,
        hasLength(WonderCollection.values.length + WonderTheme.values.length),
      );
      expect(
        ThemeFilter.tiles.first,
        const ThemeFilter.group(WonderCollection.jesus),
      );
    });

    test('none is empty, and each has a label', () {
      for (final tile in ThemeFilter.tiles) {
        expect(
          repo.byThemeFilter(tile),
          isNotEmpty,
          reason: 'the picker would offer $tile and then show an empty list',
        );
        expect(repo.labelForFilter(tile), isNotEmpty);
      }
    });

    test('kinds and collections do not collide on id', () {
      // ThemeFilter.id flattens the two into one namespace, and read-aloud
      // names the page from it.
      final ids = ThemeFilter.tiles.map((t) => t.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('a filter equals another built the same way', () {
      // PathState is compared by value all over the browsing tests, and the
      // picker uses tiles as map keys.
      expect(
        const ThemeFilter.theme(WonderTheme.healing),
        const ThemeFilter.theme(WonderTheme.healing),
      );
      expect(
        const ThemeFilter.theme(WonderTheme.healing),
        isNot(const ThemeFilter.group(WonderCollection.jesus)),
      );
    });
  });
}
