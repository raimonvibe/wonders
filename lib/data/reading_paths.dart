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

/// One tile in the "By theme" picker: a [WonderTheme], or a
/// [WonderCollection] that cuts across them.
///
/// The picker offers both because they answer different questions about the
/// same card — Healings is *what kind of wonder*, Wonders of Jesus is *whose*
/// — and one card is very often an answer to both at once. Keeping them as two
/// axes is what lets the Jesus tile exist without emptying the seven kinds;
/// see [WonderCollection].
class ThemeFilter {
  const ThemeFilter.theme(WonderTheme theme)
      : kind = theme,
        collection = null;

  const ThemeFilter.group(WonderCollection group)
      : kind = null,
        collection = group;

  /// Exactly one of these is set.
  final WonderTheme? kind;
  final WonderCollection? collection;

  /// Every tile the picker offers, in the order it shows them.
  ///
  /// Collections lead. Jesus is what most readers open this path looking for,
  /// and putting it first also reads as what it is — a way through the seven
  /// below it rather than an eighth peer.
  static final List<ThemeFilter> tiles = List.unmodifiable([
    for (final c in WonderCollection.values) ThemeFilter.group(c),
    for (final t in WonderTheme.values) ThemeFilter.theme(t),
  ]);

  /// Stable id, for anything that has to name the filter — the read-aloud page
  /// name, for one. Kinds and collections share the one namespace.
  String get id => kind?.id ?? collection!.id;

  @override
  bool operator ==(Object other) =>
      other is ThemeFilter &&
      other.kind == kind &&
      other.collection == collection;

  @override
  int get hashCode => Object.hash(kind, collection);

  @override
  String toString() => 'ThemeFilter($id)';
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
  final ThemeFilter? theme;
  final WonderEra? era;

  final String query;

  PathState copyWith({
    ReadingPath? path,
    SortMode? sort,
    ThemeFilter? theme,
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
