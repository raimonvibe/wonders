import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/mark.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/palette.dart';
import '../share/share_service.dart' show shareOrigin;
import 'library_export.dart';

/// Everything the reader has kept.
///
/// Newest first, because the thing you marked this morning is the thing you
/// are looking for. Filtering is by colour only — the colours are the reader's
/// own filing system, and a second axis would be inventing one for them.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  HighlightColour? _filter;

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themeProvider);
    final all = ref.watch(marksProvider);
    final marks =
        _filter == null ? all : all.where((m) => m.colour == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kept verses'),
        actions: [
          if (all.isNotEmpty) ...[
            IconButton(
              tooltip: 'Export these verses',
              icon: const Icon(Icons.ios_share),
              onPressed: () => _export(context, all),
            ),
            IconButton(
              tooltip: 'Remove every mark',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context),
            ),
          ],
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.pageGradient),
        child: all.isEmpty
            ? const _Empty()
            : Column(
                children: [
                  _Filters(
                    all: all,
                    selected: _filter,
                    onSelect: (colour) => setState(() => _filter = colour),
                  ),
                  Expanded(
                    child: marks.isEmpty
                        ? const Center(
                            child: Text('Nothing in that colour yet.'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: marks.length,
                            itemBuilder: (context, index) =>
                                _MarkTile(mark: marks[index]),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Exports every mark, not just the filtered ones — a backup that quietly
  /// omitted three colours because a chip was selected would be worse than none.
  Future<void> _export(BuildContext context, List<Mark> marks) async {
    final messenger = ScaffoldMessenger.of(context);
    final origin = shareOrigin(context);
    try {
      await LibraryExport.share(marks, origin: origin);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not export: $error')),
      );
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove every mark?'),
        content: const Text(
          'Every kept verse and every note goes with it. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep them'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove all'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(marksProvider.notifier).removeAll();
    }
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.all,
    required this.selected,
    required this.onSelect,
  });

  final List<Mark> all;
  final HighlightColour? selected;
  final ValueChanged<HighlightColour?> onSelect;

  @override
  Widget build(BuildContext context) {
    // Only offer a colour the reader has actually used, so the row never
    // promises a filter that leads to an empty list.
    final used = HighlightColour.values
        .where((c) => all.any((m) => m.colour == c))
        .toList();
    if (used.length < 2) return const SizedBox(height: 8);

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('All ${all.length}'),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          for (final colour in used)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: CircleAvatar(backgroundColor: colour.edge, radius: 7),
                label: Text('${all.where((m) => m.colour == colour).length}'),
                selected: selected == colour,
                onSelected: (_) => onSelect(colour),
              ),
            ),
        ],
      ),
    );
  }
}

class _MarkTile extends ConsumerWidget {
  const _MarkTile({required this.mark});

  final Mark mark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themeProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // Straight into the chapter, on the verse. A saved verse you cannot
        // get back to in one tap is a list, not a bookmark.
        onTap: () => context.go(
          '/bible/${mark.bookId}/${mark.chapterId.split('.').last}',
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: mark.colour.edge, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    mark.reference,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: mark.colour.edge,
                    ),
                  ),
                  const Spacer(),
                  if (mark.hasNote)
                    Icon(
                      Icons.sticky_note_2_outlined,
                      size: 15,
                      color: palette.shade300,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                mark.preview,
                style: AppTheme.verseStyle(palette, fontSize: 15),
              ),
              if (mark.hasNote) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.shade900.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    mark.note!,
                    style: TextStyle(fontSize: 14, color: palette.shade100),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_border, size: 40, color: Palette.accent),
            const SizedBox(height: 16),
            Text(
              'Nothing kept yet.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Press and hold any verse while you are reading to mark it in '
              'colour, and add a note if you want to.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
