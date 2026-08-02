import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/reading_paths.dart';
import '../../models/wonder.dart';
import '../../providers.dart';
import '../../theme/metrics.dart';
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
        child: CustomScrollView(
          slivers: [
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

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
            // Wrapped, not scrolled sideways. The four labels come to about
            // forty characters, which has never fitted one row on a phone: the
            // horizontal list this replaces left "Full catalog" off the right
            // edge with nothing to suggest it was there, so the fourth way into
            // the catalog was invisible unless you happened to swipe a row that
            // does not look scrollable. Wrapping costs a second row and shows
            // all four at any width and any text size.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final path in ReadingPath.values)
                      ChoiceChip(
                        label: Text(path.label),
                        selected: state.path == path,
                        // The fill already says which path is chosen, and the
                        // tick was costing the width that pushed the last chip
                        // off screen.
                        showCheckmark: false,
                        onSelected: (_) => controller.setPath(path),
                      ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  state.path.blurb,
                  style: TextStyle(color: palette.shade200, fontSize: 13),
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
                SliverList.builder(
                  itemCount: wonders.length,
                  itemBuilder: (context, index) =>
                      _WonderTile(wonder: wonders[index]),
                ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
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
          return Card(
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
                      '${counts[entry.key] ?? 0}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
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
          Row(
            children: [
              Text(count == 1 ? '1 wonder' : '$count wonders'),
              const Spacer(),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
  }
}

class _WonderTile extends ConsumerWidget {
  const _WonderTile({required this.wonder});

  final Wonder wonder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themeProvider);
    return ListTile(
      title: Text(wonder.title),
      subtitle: Text(
        wonder.passage.label,
        style: TextStyle(color: palette.shade300, fontSize: 12),
      ),
      trailing: wonder.hasParallels
          ? Icon(Icons.call_split, size: 16, color: palette.shade400)
          : null,
      onTap: () => context.go('/wonders/${wonder.id}'),
    );
  }
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Continue where you left off'),
          subtitle: Text(wonder.title),
          onTap: () => context.go('/wonders/${wonder.id}'),
        ),
      ),
    );
  }
}
