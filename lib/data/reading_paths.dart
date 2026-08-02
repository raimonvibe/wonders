import '../models/wonder.dart';

/// The four ways into the catalog, ported from ../../lib/wonders/paths.ts.
enum ReadingPath {
  startHere('start-here'),
  theme('theme'),
  era('era'),
  catalog('catalog');

  const ReadingPath(this.id);
  final String id;

  static ReadingPath parse(String? id) => values.firstWhere(
        (p) => p.id == id,
        orElse: () => ReadingPath.startHere,
      );

  String get label => switch (this) {
        ReadingPath.startHere => 'Start here',
        ReadingPath.theme => 'By theme',
        ReadingPath.era => 'By book or era',
        ReadingPath.catalog => 'Full catalog',
      };

  String get blurb => switch (this) {
        ReadingPath.startHere =>
          'The best-known wonders, in a short path you can actually finish.',
        ReadingPath.theme =>
          'Healings, rescues, provision — read one kind at a time.',
        ReadingPath.era =>
          'Walk a stretch of the story: the Torah, the kingdoms, one Gospel.',
        ReadingPath.catalog =>
          'Every wonder in the catalog, sorted however you like.',
      };
}

enum SortMode {
  bible('bible'),
  bestKnown('best-known');

  const SortMode(this.id);
  final String id;

  static SortMode parse(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => SortMode.bible);

  String get label =>
      this == SortMode.bible ? 'Bible order' : 'Best known first';
}

/// Which path the reader is on, and how the list under it is filtered.
class PathState {
  const PathState({
    this.path = ReadingPath.startHere,
    this.sort = SortMode.bible,
    this.theme,
    this.era,
    this.query = '',
  });

  final ReadingPath path;
  final SortMode sort;

  /// Active filter when [path] is theme or era; null means "show the picker".
  final WonderTheme? theme;
  final WonderEra? era;

  final String query;

  PathState copyWith({
    ReadingPath? path,
    SortMode? sort,
    WonderTheme? theme,
    WonderEra? era,
    String? query,
    bool clearTheme = false,
    bool clearEra = false,
  }) {
    return PathState(
      path: path ?? this.path,
      sort: sort ?? this.sort,
      theme: clearTheme ? null : (theme ?? this.theme),
      era: clearEra ? null : (era ?? this.era),
      query: query ?? this.query,
    );
  }
}
