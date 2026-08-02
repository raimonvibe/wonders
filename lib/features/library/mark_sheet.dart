import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bible.dart';
import '../../models/mark.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';

/// What a long press on a verse opens.
///
/// One sheet for the whole feature: pick a colour to keep the verse, tap the
/// colour it already has to let it go, and add a note if there is something to
/// say. Marking and un-marking are the same gesture, so there is nothing to
/// learn beyond "press and hold".
Future<void> showMarkSheet(
  BuildContext context, {
  required Verse verse,
  required String reference,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      // Lifts the sheet clear of the keyboard when the note field has focus.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _MarkSheet(verse: verse, reference: reference),
    ),
  );
}

class _MarkSheet extends ConsumerStatefulWidget {
  const _MarkSheet({required this.verse, required this.reference});

  final Verse verse;
  final String reference;

  @override
  ConsumerState<_MarkSheet> createState() => _MarkSheetState();
}

class _MarkSheetState extends ConsumerState<_MarkSheet> {
  late final TextEditingController _note;
  bool _writingNote = false;

  Mark? get _existing =>
      ref.read(marksInChapterProvider(widget.verse.chapterId))[widget.verse
          .number];

  @override
  void initState() {
    super.initState();
    final existing = _existing;
    _note = TextEditingController(text: existing?.note ?? '');
    _writingNote = existing?.hasNote ?? false;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _apply(HighlightColour colour) async {
    final existing = _existing;

    // Tapping the colour a verse already wears, with nothing written on it,
    // means "unmark". A note is worth more than a colour, so a verse carrying
    // one is never removed by a colour tap.
    if (existing != null && existing.colour == colour && !_writingNote) {
      await ref
          .read(marksProvider.notifier)
          .remove(widget.verse.chapterId, widget.verse.number);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    await ref.read(marksProvider.notifier).save(
          Mark(
            id: existing?.id,
            chapterId: widget.verse.chapterId,
            verse: widget.verse.number,
            bookId: widget.verse.bookId,
            reference: widget.reference,
            preview: Mark.previewOf(widget.verse.text),
            colour: colour,
            note: _writingNote ? _note.text : existing?.note,
            createdAt: existing?.createdAt ?? DateTime.now(),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    await ref
        .read(marksProvider.notifier)
        .remove(widget.verse.chapterId, widget.verse.number);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themeProvider);
    final existing = ref.watch(
      marksInChapterProvider(widget.verse.chapterId),
    )[widget.verse.number];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.reference,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              widget.verse.text,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.verseStyle(palette, fontSize: 15),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                for (final colour in HighlightColour.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _Swatch(
                      colour: colour,
                      selected: existing?.colour == colour,
                      onTap: () => _apply(colour),
                    ),
                  ),
                const Spacer(),
                if (existing != null)
                  IconButton(
                    tooltip: 'Remove this mark',
                    onPressed: _remove,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),

            if (!_writingNote)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _writingNote = true),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Add a note'),
                ),
              )
            else ...[
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                autofocus: true,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'What you want to remember about this verse',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                // Writing a note on an unmarked verse marks it too, in the
                // default colour — a note with nothing holding it would be
                // invisible in the reader and unfindable in the library.
                onPressed: () =>
                    _apply(existing?.colour ?? HighlightColour.amber),
                child: const Text('Save'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  final HighlightColour colour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: colour.label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colour.fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: colour.edge,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected
              ? Icon(Icons.check, size: 18, color: colour.edge)
              : null,
        ),
      ),
    );
  }
}
