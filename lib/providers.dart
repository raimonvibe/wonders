import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/bible_repository.dart';
import 'data/library_repository.dart';
import 'data/prefs.dart';
import 'data/reading_paths.dart';
import 'data/wonders_repository.dart';
import 'features/speech/speech_controller.dart';
import 'models/bible.dart';
import 'models/mark.dart';
import 'models/wonder.dart';
import 'theme/app_theme.dart';
import 'theme/palette.dart';

/// The three things every screen reads. Overridden in main() with the
/// already-resolved instances so no screen has to handle a loading state for
/// data that is bundled with the app.
final prefsProvider = Provider<Prefs>((ref) {
  throw UnimplementedError('prefsProvider must be overridden in main()');
});

final wondersProvider = Provider<WondersRepository>((ref) {
  throw UnimplementedError('wondersProvider must be overridden in main()');
});

final bibleProvider = Provider<BibleRepository>((ref) {
  throw UnimplementedError('bibleProvider must be overridden in main()');
});

/* --- theme ---------------------------------------------------------------- */

/// Which testament the reader is currently in. The app wears pine while you
/// are in the Old Testament and ocean in the New, unless the palette is
/// pinned in settings.
class ThemeController extends StateNotifier<Palette> {
  ThemeController(this._prefs)
      : super(
          AppTheme.paletteFor(
            Testament.parse(_prefs.themeLock ?? Testament.old.id),
          ),
        );

  final Prefs _prefs;

  bool get isLocked => _prefs.themeLock != null;

  /// Called as the reader moves through scripture. A no-op while the palette
  /// is pinned, so a deliberate choice is never overridden by navigation.
  void followTestament(Testament testament) {
    if (isLocked) return;
    final next = AppTheme.paletteFor(testament);
    if (next != state) state = next;
  }

  Future<void> lockTo(Testament? testament) async {
    await _prefs.setThemeLock(testament?.id);
    if (testament != null) state = AppTheme.paletteFor(testament);
  }
}

final themeProvider = StateNotifierProvider<ThemeController, Palette>((ref) {
  return ThemeController(ref.watch(prefsProvider));
});

/// Reading size, as its own state.
///
/// It cannot just be read off [prefsProvider]: that provider hands back the
/// same Prefs instance every time, so a screen watching it never rebuilds when
/// a value inside changes. Anything the UI has to react to needs a provider of
/// its own; Prefs stays the place it is persisted.
class FontScaleController extends StateNotifier<double> {
  FontScaleController(this._prefs) : super(_prefs.fontScale);

  final Prefs _prefs;

  void set(double value) {
    state = value;
    _save(_prefs.setFontScale(value));
  }
}

final fontScaleProvider =
    StateNotifierProvider<FontScaleController, double>((ref) {
  return FontScaleController(ref.watch(prefsProvider));
});

/// The wonder last opened, for "continue where you left off". Same reasoning
/// as [fontScaleProvider].
class LastWonderController extends StateNotifier<String?> {
  LastWonderController(this._prefs) : super(_prefs.lastWonderId);

  final Prefs _prefs;

  void set(String id) {
    state = id;
    _save(_prefs.setLastWonderId(id));
  }
}

final lastWonderProvider =
    StateNotifierProvider<LastWonderController, String?>((ref) {
  return LastWonderController(ref.watch(prefsProvider));
});

/// The chapter last read, so the Bible tab can offer it back.
///
/// Prefs has recorded this on every chapter turn since the reader was written;
/// nothing ever read it, so the Bible tab opened on all 66 books however deep
/// into Leviticus you were. The Wonders tab has had its resume card all along.
class LastChapterController extends StateNotifier<String?> {
  LastChapterController(this._prefs) : super(_prefs.lastChapterId);

  final Prefs _prefs;

  void set(String id) {
    if (state == id) return;
    state = id;
    _save(_prefs.setLastChapterId(id));
  }
}

final lastChapterProvider =
    StateNotifierProvider<LastChapterController, String?>((ref) {
  return LastChapterController(ref.watch(prefsProvider));
});

/// The [Chapter] behind [lastChapterProvider], or null on a first run.
final lastChapterDetailProvider = FutureProvider<Chapter?>((ref) async {
  final id = ref.watch(lastChapterProvider);
  if (id == null) return null;
  return ref.watch(bibleProvider).chapter(id);
});

/* --- the reader's own marks ----------------------------------------------- */

final libraryProvider = Provider<LibraryRepository>((ref) {
  throw UnimplementedError('libraryProvider must be overridden in main()');
});

/// Every marked verse, newest first, held in memory.
///
/// The reader renders one decoration per verse per frame, so looking a mark up
/// has to be a map read rather than a query. Writes go to both at once: the
/// list here for the UI, the database for the next launch.
class LibraryController extends StateNotifier<List<Mark>> {
  LibraryController(this._repo, List<Mark> initial) : super(initial);

  final LibraryRepository _repo;

  Future<void> save(Mark mark) async {
    final saved = await _repo.save(mark);
    state = [
      saved,
      for (final existing in state)
        if (existing.chapterId != saved.chapterId ||
            existing.verse != saved.verse)
          existing,
    ];
  }

  Future<void> remove(String chapterId, int verse) async {
    await _repo.remove(chapterId, verse);
    state = [
      for (final mark in state)
        if (mark.chapterId != chapterId || mark.verse != verse) mark,
    ];
  }

  Future<void> removeAll() async {
    await _repo.removeAll();
    state = const [];
  }
}

final marksProvider =
    StateNotifierProvider<LibraryController, List<Mark>>((ref) {
  throw UnimplementedError('marksProvider must be overridden in main()');
});

/// The marks in one chapter, by verse number — what the reader looks up.
final marksInChapterProvider =
    Provider.family<Map<int, Mark>, String>((ref, chapterId) {
  return {
    for (final mark in ref.watch(marksProvider))
      if (mark.chapterId == chapterId) mark.verse: mark,
  };
});

/* --- read aloud ----------------------------------------------------------- */

/// The app's one voice.
///
/// Resolved in main() like the repositories above, and for a reason particular
/// to this one: SpeechAudioHandler wraps the same instance for the lock screen,
/// and AudioService.init has to be handed it before the first frame. A
/// controller built lazily here would be a second one, and the notification
/// would be driving a queue nobody could see.
final speechProvider =
    StateNotifierProvider<SpeechController, SpeechState>((ref) {
  throw UnimplementedError('speechProvider must be overridden in main()');
});

/* --- catalog browsing ----------------------------------------------------- */

class PathController extends StateNotifier<PathState> {
  PathController(this._prefs)
      : super(PathState(path: _prefs.path, sort: _prefs.sort));

  final Prefs _prefs;

  /// Changing path resets the query as well as the filters.
  ///
  /// It has to: the search box only exists on the list, so leaving a query
  /// behind while the picker is up means the reader comes back to a box that
  /// renders empty and a list filtered by a word they can no longer see. That
  /// is what made picking a theme look like it did nothing at all.
  void setPath(ReadingPath path) {
    state = state.copyWith(
      path: path,
      clearTheme: true,
      clearEra: true,
      query: '',
    );
    _save(_prefs.setPath(path));
  }

  void setSort(SortMode sort) {
    state = state.copyWith(sort: sort);
    _save(_prefs.setSort(sort));
  }

  /// Same reasoning as [setPath]: crossing between the picker and the list
  /// takes the search box with it, so the query goes too.
  void setTheme(WonderTheme? theme) => state = theme == null
      ? state.copyWith(clearTheme: true, query: '')
      : state.copyWith(theme: theme, query: '');

  void setEra(WonderEra? era) => state = era == null
      ? state.copyWith(clearEra: true, query: '')
      : state.copyWith(era: era, query: '');

  void setQuery(String query) => state = state.copyWith(query: query);

  /// Widen the current search to the whole catalog, keeping the query.
  ///
  /// The one path change that must *not* reset the query, because carrying the
  /// query over is the entire point — it is the way out of "0 results on this
  /// path" without making the reader type the word again.
  void searchWholeCatalog() {
    state = state.copyWith(
      path: ReadingPath.catalog,
      clearTheme: true,
      clearEra: true,
    );
    _save(_prefs.setPath(ReadingPath.catalog));
  }
}

final pathProvider = StateNotifierProvider<PathController, PathState>((ref) {
  return PathController(ref.watch(prefsProvider));
});

/// The list the current path and filters resolve to — what every wonder list
/// screen renders, so sorting and searching are defined in exactly one place.
final visibleWondersProvider = Provider<List<Wonder>>((ref) {
  final repo = ref.watch(wondersProvider);
  final state = ref.watch(pathProvider);

  List<Wonder> list = switch (state.path) {
    ReadingPath.startHere => repo.startHere(),
    ReadingPath.theme =>
      state.theme == null ? const [] : repo.byTheme(state.theme!),
    ReadingPath.era => state.era == null ? const [] : repo.byEra(state.era!),
    ReadingPath.catalog => repo.wonders,
  };

  if (state.query.trim().isNotEmpty) {
    // Intersect the other way around: repo.search already returns its matches
    // best-first, and that ranking is the whole point of searching. Filtering
    // the path's list by a set of ids would throw it away.
    final inScope = list.map((w) => w.id).toSet();
    list = repo.search(state.query).where((w) => inScope.contains(w.id)).toList();
  }

  // Start Here defines its own order; re-sorting it would defeat the point.
  if (state.sort == SortMode.bestKnown && state.path != ReadingPath.startHere) {
    list = repo.byFamiliarity(list);
  }

  return list;
});

/// How many wonders the current query matches across the whole catalog,
/// ignoring the path. Zero when there is no query.
///
/// The home screen compares this against the visible list to tell "no such
/// wonder" apart from "not on this path" — without it, searching inside Start
/// Here's twenty-five is a dead end with no way out but guessing.
final catalogMatchCountProvider = Provider<int>((ref) {
  final query = ref.watch(pathProvider).query;
  if (query.trim().isEmpty) return 0;
  return ref.watch(wondersProvider).matchCount(query);
});

/// Fire-and-forget for the preference writes above: the UI has already moved
/// on, and a failed write only costs the reader their place. Named apart from
/// `dart:async`'s `unawaited`, which does not swallow the error.
void _save(Future<void> future) {
  future.catchError((Object _) {});
}
