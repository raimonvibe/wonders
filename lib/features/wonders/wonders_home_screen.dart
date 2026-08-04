import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/reading_paths.dart';
import '../../data/wonders_repository.dart';
import '../../models/wonder.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/metrics.dart';
import '../../theme/palette.dart';
import '../../theme/states.dart';
import '../speech/listen_button.dart';
import '../speech/speakables.dart';

/// The way in: pick a path, then a wonder.
///
/// The four paths, the sort toggle and the search box are the website's
/// CatalogBrowser, minus the dock. Which wonders they resolve to is decided by
/// visibleWondersProvider, not here.
class WondersHomeScreen extends ConsumerWidget {
  const WondersHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(wondersProvider);
    final state = ref.watch(pathProvider);
    final controller = ref.read(pathProvider.notifier);
    final wonders = ref.watch(visibleWondersProvider);
    final palette = ref.watch(themeProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.pageGradient),
        // The gradient stays outside this, so the colour still runs edge to
        // edge on a wide screen and only the content is brought in.
        child: LayoutBuilder(
          builder: (context, box) {
            final gutter = contentGutter(box.maxWidth);
            final columns =
                box.maxWidth - gutter * 2 >= catalogTwoColumnFrom ? 2 : 1;
            return _body(
              context,
              ref,
              gutter: gutter,
              columns: columns,
              repo: repo,
              state: state,
              controller: controller,
              wonders: wonders,
              palette: palette,
            );
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref, {
    required double gutter,
    required int columns,
    required WondersRepository repo,
    required PathState state,
    required PathController controller,
    required List<Wonder> wonders,
    required Palette palette,
  }) {
    return CustomScrollView(
      slivers: [
        // Outside the gutter on purpose. The bar is chrome rather than content,
        // and a title that starts 200 pt in reads as a layout fault on the one
        // element the reader meets first.
        SliverAppBar.large(
              title: const Text('Wonders and Hope'),
              backgroundColor: Colors.transparent,
              actions: [
                // Reads the page as it stands — what this is, which path is in
                // force, and the wonders that path resolves to. Searching or
                // switching path and pressing Listen again reads the new list.
                ListenButton(
                  sourceId: Speakables.wondersListId,
                  source: () async => Speakables.wondersList(
                    catalogCount: repo.count,
                    path: state,
                    wonders: wonders,
                  ),
                  tooltip: 'Read this page aloud',
                ),
              ],
            ),

        // Everything below the bar is content, and shares one gutter. The
        // 16 pt paddings inside each sliver are the phone's margin and stay
        // where they are; this is the margin outside them, which is 0 until
        // there is width to spare.
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          sliver: SliverMainAxisGroup(
            slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  '${repo.count} wonders, each with the passage it happened in.',
                  style: TextStyle(color: palette.shade200),
                ),
              ),
            ),

            /* --- resume ---------------------------------------------------- */
            SliverToBoxAdapter(
              child: _ResumeCard(lastId: ref.watch(lastWonderProvider)),
            ),

            /* --- the four paths -------------------------------------------- */
            //
            // The label above them is not decoration. Four chips arriving with
            // no prompt read as filters already applied rather than as a choice
            // being offered, and to a screen reader they were four unrelated
            // buttons in a row with nothing to say what they select between.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('Choose a way in', palette: palette),
                    const SizedBox(height: 10),
                    _PathChips(selected: state.path, onPick: controller.setPath),
                    const SizedBox(height: 10),
                    Text(
                      state.path.blurb,
                      style: TextStyle(color: palette.shade200, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            /* --- the filter picker, when the path needs one ---------------- */
            if (state.path == ReadingPath.theme && state.theme == null)
              _PickerGrid(
                labels: {
                  for (final t in WonderTheme.values) t: repo.labelFor(t),
                },
                counts: {
                  for (final t in WonderTheme.values) t: repo.byTheme(t).length,
                },
                onPick: controller.setTheme,
              )
            else if (state.path == ReadingPath.era && state.era == null)
              _PickerGrid(
                labels: {
                  for (final e in repo.populatedEras()) e: repo.labelForEra(e),
                },
                counts: {
                  for (final e in repo.populatedEras()) e: repo.byEra(e).length,
                },
                onPick: controller.setEra,
              )
            else ...[
              // Which theme or era is in force, and the way back to the picker.
              // Without this the only route to a second theme was to leave the
              // path and come back.
              if (state.theme != null || state.era != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        label: Text(
                          state.theme != null
                              ? repo.labelFor(state.theme!)
                              : repo.labelForEra(state.era!),
                        ),
                        onDeleted: () => state.theme != null
                            ? controller.setTheme(null)
                            : controller.setEra(null),
                        deleteIcon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: _Toolbar(
                  state: state,
                  controller: controller,
                  count: wonders.length,
                ),
              ),
              if (wonders.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyState(
                    state: state,
                    controller: controller,
                    elsewhere: ref.watch(catalogMatchCountProvider),
                  ),
                )
              else
                // One row per [columns] wonders. A Row of Expanded tiles
                // rather than a SliverGrid because a grid wants a fixed extent
                // and these rows do not have one: a title can wrap to two lines
                // and so can the list of books that also tell it. Sized by the
                // taller of the pair, the row cannot overflow at any text size,
                // which is the failure gridTileExtent exists to prevent and the
                // one a catalog of 178 rows would find.
                SliverList.builder(
                  itemCount: (wonders.length + columns - 1) ~/ columns,
                  itemBuilder: (context, row) {
                    if (columns == 1) return _WonderTile(wonder: wonders[row]);
                    final first = row * columns;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var column = 0; column < columns; column++)
                          Expanded(
                            child: first + column < wonders.length
                                ? _WonderTile(wonder: wonders[first + column])
                                // The last row of an odd count. Empty rather
                                // than absent, so the tile beside it keeps its
                                // half of the width instead of stretching to
                                // the full one.
                                : const SizedBox.shrink(),
                          ),
                      ],
                    );
                  },
                ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The four ways in, on one row where they fit and two by two where they do not.
///
/// A `Wrap` put three on the first row and left "Full catalog" alone on the
/// second, which reads as three choices and an afterthought rather than as one
/// set of four — and a ragged right edge is the loudest thing on a screen whose
/// job is to be quiet.
///
/// One row is what this wants to be, and on a tablet or a phone in landscape it
/// is what it is. On an upright phone it is not available: the four labels come
/// to forty-four characters and there is room for about half that, so the only
/// way onto one row is abbreviations — "Era", "All" — that give up the plain
/// language the rest of the app is written in. Two by two at equal widths is
/// then the arrangement that is actually balanced.
///
/// Which of the two is decided by measuring the labels rather than by a
/// breakpoint, because the thing that decides is the reader's text size as much
/// as their screen: turn the system font up and four stop fitting on a width
/// where they fitted before.
class _PathChips extends StatelessWidget {
  const _PathChips({required this.selected, required this.onPick});

  final ReadingPath selected;
  final ValueChanged<ReadingPath> onPick;

  static const _gap = 8.0;

  /// A chip is its label plus Material's padding either side, and the label
  /// wants a little air before it looks cramped against the outline.
  static const _chipChrome = 40.0;

  /// The widest a single chip is allowed to get.
  ///
  /// Equal widths are the point — see the note above — but equal is not the
  /// same as unbounded. Four chips dividing a tablet's landscape width came to
  /// 310 pt each, which puts "By theme" alone in the middle of a button three
  /// times the size of its own label and reads as a control that failed to load
  /// rather than one of four choices. Capped, they stay equal to each other and
  /// stop growing once they have the room they need.
  static const _chipMax = 200.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const paths = ReadingPath.values;
        final columns = _columnsThatFit(context, box.maxWidth);

        // Left, not centred: the section label above them starts at the
        // margin, and a row of chips floating away from it would read as a
        // separate thing rather than as the answer to it.
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _chipMax * columns + _gap * (columns - 1),
            ),
            child: Column(
              children: [
                for (var row = 0; row < paths.length; row += columns) ...[
                  if (row > 0) const SizedBox(height: _gap),
                  Row(
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) const SizedBox(width: _gap),
                        Expanded(child: _chip(paths[row + column])),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Four if all four labels fit a row at their natural width, otherwise two.
  ///
  /// Three is never right: it is the arrangement that left one chip stranded.
  static int _columnsThatFit(BuildContext context, double available) {
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);

    var widest = 0.0;
    for (final path in ReadingPath.values) {
      final painter = TextPainter(
        text: TextSpan(text: path.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      widest = widest > painter.width ? widest : painter.width;
      painter.dispose();
    }

    // Equal columns, so the widest label is what every chip has to be.
    final needed = (widest + _chipChrome) * 4 + _gap * 3;
    return needed <= available ? 4 : 2;
  }

  Widget _chip(ReadingPath path) => ChoiceChip(
        // Centred, because a chip stretched to a column's width and labelled
        // from the left has its text drifting away from the shape around it.
        label: SizedBox(
          width: double.infinity,
          child: Text(path.label, textAlign: TextAlign.center),
        ),
        selected: selected == path,
        // The fill already says which path is chosen, and the tick was costing
        // width the label wants.
        showCheckmark: false,
        onSelected: (_) => onPick(path),
      );
}

/// A grid of themes or eras. Generic over the filter type so the two pickers
/// are the same widget.
class _PickerGrid<T> extends StatelessWidget {
  const _PickerGrid({
    required this.labels,
    required this.counts,
    required this.onPick,
  });

  final Map<T, String> labels;

  /// How many wonders sit behind each tile, so the reader can see what they
  /// are choosing between before they commit to a tap.
  final Map<T, int> counts;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    final entries = labels.entries.toList();
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          // Two lines, because the longest labels — "Acts and the early
          // church", "Signs and appearances" — wrap at this width, and measured
          // rather than guessed so a larger system font still fits.
          mainAxisExtent: gridTileExtent(
            context,
            titleLines: 2,
            subtitleLines: 1,
            chrome: 28,
          ),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final count = counts[entry.key] ?? 0;
          // "Healing" over a bare "34" left the reader to guess what was being
          // counted — chapters? verses? books? It is one word, and it fits.
          final tally = count == 1 ? '1 wonder' : '$count wonders';

          return Semantics(
            button: true,
            label: '${entry.value}, $tally',
            excludeSemantics: true,
            child: Card(
              // The grid already spaces these; Card's own 4pt margin was eating
              // height the label needed.
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onPick(entry.key),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.value,
                        // Paired with titleLines above: without a cap, a longer
                        // label would find a third line and overflow again.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tally,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The search box and the sort toggle.
///
/// Stateful for one reason: the text box needs a controller. Left uncontrolled
/// it keeps its own private copy of the text, which silently drifts from
/// PathState.query whenever the widget is rebuilt from scratch — crossing to
/// the theme picker and back used to leave a visibly empty box still filtering
/// the list by the old word.
class _Toolbar extends StatefulWidget {
  const _Toolbar({
    required this.state,
    required this.controller,
    required this.count,
  });

  final PathState state;
  final PathController controller;
  final int count;

  @override
  State<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<_Toolbar> {
  late final TextEditingController _text =
      TextEditingController(text: widget.state.query);

  @override
  void didUpdateWidget(_Toolbar old) {
    super.didUpdateWidget(old);
    // The query can change from outside — setPath clears it. Follow it, but
    // never while the reader is mid-word, or the cursor would jump.
    if (widget.state.query != _text.text) {
      _text.value = TextEditingValue(
        text: widget.state.query,
        selection: TextSelection.collapsed(offset: widget.state.query.length),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;
    final count = widget.count;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _text,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search wonders, people and places',
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: state.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                      onPressed: () => controller.setQuery(''),
                    ),
            ),
            onChanged: controller.setQuery,
          ),
          const SizedBox(height: 10),
          // A Wrap, not a Row. "Bible order" and "Best known" inside a
          // SegmentedButton come to most of a phone's width on their own, so
          // the count beside them overflowed the moment the reader turned their
          // system font up — the one setting a person who is struggling to read
          // is most likely to have already changed. Wrapping drops the sort
          // control onto its own line instead of striping the screen.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text(count == 1 ? '1 wonder' : '$count wonders'),
              // Start Here is already an order; offering to re-sort it would
              // undo the curation.
              if (state.path != ReadingPath.startHere)
                SegmentedButton<SortMode>(
                  segments: const [
                    ButtonSegment(
                      value: SortMode.bible,
                      label: Text('Bible order'),
                    ),
                    ButtonSegment(
                      value: SortMode.bestKnown,
                      label: Text('Best known'),
                    ),
                  ],
                  selected: {state.sort},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => controller.setSort(s.first),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What stands in for the list when nothing matches.
///
/// The important case is the middle one. Searching inside Start Here means
/// searching twenty-five wonders, so a perfectly good query can match nothing
/// here while matching plenty in the catalog. Saying so — and offering the one
/// tap that widens the search — is the difference between a dead end and a
/// narrow path.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.state,
    required this.controller,
    required this.elsewhere,
  });

  final PathState state;
  final PathController controller;

  /// Matches across the whole catalog, whatever the current path is.
  final int elsewhere;

  @override
  Widget build(BuildContext context) {
    final query = state.query.trim();
    final scoped = state.path != ReadingPath.catalog;

    final String message;
    Widget? action;

    if (query.isEmpty) {
      message = 'Nothing here yet.';
    } else if (elsewhere > 0 && scoped) {
      message = 'No match for “$query” on ${state.path.label.toLowerCase()}.';
      action = FilledButton.tonal(
        onPressed: controller.searchWholeCatalog,
        child: Text(
          elsewhere == 1
              ? 'Search the full catalog (1 match)'
              : 'Search the full catalog ($elsewhere matches)',
        ),
      );
    } else {
      message = 'No wonder matches “$query”.';
      action = TextButton(
        onPressed: () => controller.setQuery(''),
        child: const Text('Clear search'),
      );
    }

    return EmptyState(
      icon: query.isEmpty ? Icons.auto_awesome_outlined : Icons.search_off,
      title: message,
      action: action,
    );
  }
}

class _WonderTile extends ConsumerWidget {
  const _WonderTile({required this.wonder});

  final Wonder wonder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(wondersProvider);
    final palette = ref.watch(themeProvider);
    final parallels = repo.parallelsOf(wonder);

    // The reference, and then who else tells it. A branching-arrow icon was
    // carrying "this event is told more than once" on its own, which is a lot
    // to ask of a 16pt glyph with no label: it meant nothing on sight and
    // nothing at all to a screen reader, which read the row as the title and
    // stopped. The book names are shorter than the icon was wide.
    final subtitle = parallels.isEmpty
        ? wonder.passage.label
        : '${wonder.passage.label} · also in '
            '${parallels.map((w) => w.passage.bookName).join(', ')}';

    return ListTile(
      // Which testament, before the tap rather than after it. Opening a card
      // repaints the whole app green or blue, and until now nothing on the way
      // in said which it would be — the colour change read as a glitch. It is
      // the same left rule a kept verse wears, so it is a mark the reader has
      // already met.
      leading: _TestamentRule(testament: wonder.testament),
      // ListTile reserves an icon's worth of room for a leading widget, and a
      // 4pt rule floating in 40pt of space reads as a rendering fault. Told the
      // truth about its width, it sits against the margin like the rule on a
      // kept verse does.
      minLeadingWidth: 4,
      horizontalTitleGap: 14,
      title: Text(wonder.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        // The app's own palette, not the wonder's. The rule already says which
        // testament this is; colouring the reference too would put two greens
        // and two blues in one list of text and read as an inconsistency
        // rather than as a second copy of the same fact.
        style: TextStyle(color: palette.shade300, fontSize: 12),
      ),
      onTap: () => context.go('/wonders/${wonder.id}'),
    );
  }
}

/// Green for the Old Testament, blue for the New.
///
/// Stated against the fixed palettes rather than the one the app is wearing,
/// because the whole point is to tell two rows in the same list apart.
class _TestamentRule extends StatelessWidget {
  const _TestamentRule({required this.testament});

  final Testament testament;

  @override
  Widget build(BuildContext context) => Semantics(
        label: testament.label,
        child: Container(
          width: 4,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.paletteFor(testament).shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _ResumeCard extends ConsumerWidget {
  const _ResumeCard({required this.lastId});

  final String? lastId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = lastId;
    if (id == null) return const SizedBox.shrink();
    final wonder = ref.watch(wondersProvider).byId(id);
    if (wonder == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.history, color: Palette.accent),
          title: const Text('Continue where you left off'),
          subtitle: Text(wonder.title),
          // Neither resume card said it was tappable. The one control on the
          // More tab that leads somewhere carries a chevron, so the two cards
          // that lead somewhere should carry one too.
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/wonders/${wonder.id}'),
        ),
      ),
    );
  }
}
