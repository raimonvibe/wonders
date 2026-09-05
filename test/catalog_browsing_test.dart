import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/data/reading_paths.dart';
import 'package:bible_wonders/data/wonders_repository.dart';
import 'package:bible_wonders/models/wonder.dart';
import 'package:bible_wonders/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The path, the filters and the query, as one piece of state.
///
/// These cover the bug where picking a theme appeared to do nothing: the query
/// survived the path change while the search box that held it did not, so the
/// list was filtered by a word the reader could no longer see.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WondersRepository repo;

  setUpAll(() async {
    repo = await WondersRepository.load();
  });

  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await Prefs.load();
    final container = ProviderContainer(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        wondersProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('a query does not outlive its search box', () {
    test('changing path clears it', () async {
      final container = await makeContainer();
      final controller = container.read(pathProvider.notifier);

      controller.setQuery('jesus');
      expect(container.read(pathProvider).query, 'jesus');

      controller.setPath(ReadingPath.theme);
      expect(container.read(pathProvider).query, isEmpty);
    });

    test('picking a theme then shows that theme', () async {
      final container = await makeContainer();
      final controller = container.read(pathProvider.notifier);

      // Exactly the sequence from the bug report: search on Start Here, get
      // nothing, switch to By theme, pick one.
      controller.setQuery('jesus');
      controller.setPath(ReadingPath.theme);
      controller.setTheme(const ThemeFilter.theme(WonderTheme.healing));

      final visible = container.read(visibleWondersProvider);
      expect(visible, isNotEmpty);
      expect(visible.length, repo.byTheme(WonderTheme.healing).length);
    });

    test('picking an era then shows that era', () async {
      final container = await makeContainer();
      final controller = container.read(pathProvider.notifier);

      controller.setQuery('nothing-matches-this');
      controller.setPath(ReadingPath.era);
      controller.setEra(WonderEra.mark);

      expect(container.read(visibleWondersProvider), isNotEmpty);
    });

    test('clearing a theme returns to the picker', () async {
      final container = await makeContainer();
      final controller = container.read(pathProvider.notifier);

      controller.setPath(ReadingPath.theme);
      controller.setTheme(const ThemeFilter.theme(WonderTheme.rescue));
      expect(
        container.read(pathProvider).theme,
        const ThemeFilter.theme(WonderTheme.rescue),
      );

      controller.setTheme(null);
      expect(container.read(pathProvider).theme, isNull);
    });
  });

  group('searching within a path', () {
    test('is scoped to that path', () async {
      final container = await makeContainer();
      final controller = container.read(pathProvider.notifier);

      controller.setPath(ReadingPath.catalog);
      controller.setQuery('jesus');
      final wide = container.read(visibleWondersProvider).length;

      controller.setPath(ReadingPath.era);
      controller.setEra(WonderEra.mark);
      controller.setQuery('jesus');
      final narrow = container.read(visibleWondersProvider).length;

      expect(narrow, greaterThan(0));
      expect(narrow, lessThan(wide));
    });

    test('reports matches that exist outside the current path', () async {
      final container = await makeContainer();
      final controller = container.read(pathProvider.notifier);

      controller.setPath(ReadingPath.era);
      controller.setEra(WonderEra.torah);
      controller.setQuery('synagogue');

      // No synagogue in the Torah, ten in the Gospels — this is the number
      // that lets the empty state offer a way out instead of a dead end.
      expect(container.read(visibleWondersProvider), isEmpty);
      expect(container.read(catalogMatchCountProvider), greaterThan(0));
    });

    test('widening to the full catalog keeps the query', () async {
      final container = await makeContainer();
      final controller = container.read(pathProvider.notifier);

      controller.setPath(ReadingPath.era);
      controller.setEra(WonderEra.torah);
      controller.setQuery('synagogue');

      controller.searchWholeCatalog();

      final state = container.read(pathProvider);
      expect(state.path, ReadingPath.catalog);
      expect(state.era, isNull);
      expect(state.query, 'synagogue');
      expect(container.read(visibleWondersProvider), isNotEmpty);
    });

    test('reaches the whole catalog from the theme picker', () async {
      final container = await makeContainer();
      final controller = container.read(pathProvider.notifier);

      // On By theme with nothing picked, the page is a grid of tiles and there
      // is no list under it.
      controller.setPath(ReadingPath.theme);
      expect(container.read(visibleWondersProvider), isEmpty);

      // A word typed there is a question about the catalog, not about a theme
      // the reader has not chosen — so it finds everything a search on Full
      // catalog would, in the same best-first order.
      controller.setQuery('jesus');
      expect(
        container.read(visibleWondersProvider).map((w) => w.id).toList(),
        repo.search('jesus').map((w) => w.id).toList(),
      );

      // And clearing it puts the tiles back.
      controller.setQuery('');
      expect(container.read(visibleWondersProvider), isEmpty);
    });

    test('reaches the whole catalog from the era picker', () async {
      final container = await makeContainer();
      final controller = container.read(pathProvider.notifier);

      controller.setPath(ReadingPath.era);
      expect(container.read(visibleWondersProvider), isEmpty);

      controller.setQuery('bethesda');
      final visible = container.read(visibleWondersProvider);
      expect(visible, isNotEmpty);
      expect(
        visible.map((w) => w.id).toList(),
        repo.search('bethesda').map((w) => w.id).toList(),
      );
    });

    test('a picker search that finds nothing has nothing to widen to',
        () async {
      final container = await makeContainer();
      final controller = container.read(pathProvider.notifier);

      controller.setPath(ReadingPath.theme);
      controller.setQuery('zzzznotawonder');

      // The picker already searched everything, so the empty state must not
      // offer "search the full catalog" as though there were somewhere left.
      expect(container.read(visibleWondersProvider), isEmpty);
      expect(container.read(catalogMatchCountProvider), 0);
    });

    test('picking a theme still narrows to that theme', () async {
      final container = await makeContainer();
      final controller = container.read(pathProvider.notifier);

      // The tiles are only tappable with the box empty, but the query must go
      // either way — a leftover word would silently narrow the theme.
      controller.setPath(ReadingPath.theme);
      controller.setQuery('jesus');
      controller.setTheme(const ThemeFilter.theme(WonderTheme.healing));

      expect(container.read(pathProvider).query, isEmpty);
      expect(
        container.read(visibleWondersProvider).length,
        repo.byTheme(WonderTheme.healing).length,
      );
    });

    test('keeps search order rather than the path order', () async {
      final container = await makeContainer();
      final controller = container.read(pathProvider.notifier);

      controller.setPath(ReadingPath.catalog);
      controller.setQuery('sea');

      final visible = container.read(visibleWondersProvider);
      expect(visible, isNotEmpty);
      expect(
        visible.map((w) => w.id).toList(),
        repo
            .search('sea')
            .map((w) => w.id)
            .toList(),
      );
    });
  });
}
