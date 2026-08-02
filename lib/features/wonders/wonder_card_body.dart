import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/wonders_repository.dart';
import '../../models/wonder.dart';
import '../../providers.dart';
import '../../theme/palette.dart';
import '../speech/speakables.dart';

/// One wonder card. The counterpart of ../../components/WonderCardBody.tsx,
/// and like it, shared by every place a card appears.
///
/// While this card is being read aloud the section being spoken is tinted, so
/// listening and reading do not drift apart. The anchors come from
/// [Speakables.card] — the two have to agree, and that is the only coupling
/// between them.
class WonderCardBody extends ConsumerWidget {
  const WonderCardBody({
    super.key,
    required this.wonder,
    this.onReadPassage,
  });

  final Wonder wonder;

  /// Null in contexts with no passage page to move to, such as the tour.
  final VoidCallback? onReadPassage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themeProvider);
    final repo = ref.watch(wondersProvider);
    final parallels = repo.parallelsOf(wonder);

    // Only this card's own reading marks it. "Both" reuses the card's anchors,
    // so it counts too; a chapter being read on another screen does not.
    final active = ref.watch(
      speechProvider.select((s) {
        final mine = s.isSource(Speakables.cardId(wonder)) ||
            s.isSource(Speakables.bothId(wonder));
        return mine ? s.anchor : null;
      }),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      children: [
        _Spoken(
          active: active == 'chips',
          child: _Chips(wonder: wonder, repo: repo, palette: palette),
        ),
        const SizedBox(height: 20),

        if (wonder.quote != null)
          _Spoken(
            active: active == 'quote',
            child: _PullQuote(
              quote: wonder.quote!,
              reference: wonder.quoteRef ?? wonder.passage.label,
              palette: palette,
            ),
          ),

        if (onReadPassage != null) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onReadPassage,
            icon: const Icon(Icons.menu_book_outlined),
            label: Text('Read ${wonder.passage.label}'),
          ),
        ],

        if (wonder.location != null) ...[
          const SizedBox(height: 20),
          _Spoken(
            active: active == 'location',
            child: Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: palette.shade300),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    wonder.location!,
                    style: TextStyle(color: palette.shade200, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (wonder.details.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionTitle('Notable details', palette: palette),
          const SizedBox(height: 10),
          for (var i = 0; i < wonder.details.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Spoken(
                active: active == 'details:$i',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 10),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Palette.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(child: Text(wonder.details[i])),
                  ],
                ),
              ),
            ),
        ],

        _Prose(
          'What happened',
          wonder.whatHappened,
          palette: palette,
          active: active == 'whatHappened',
        ),
        _Prose(
          'What it says about hope',
          wonder.hopeMeaning,
          palette: palette,
          active: active == 'hopeMeaning',
        ),

        // Rule (a) from PLAN.md: a parallel account has to say what *it*
        // stresses that the others do not, or the cards are interchangeable.
        if (wonder.distinctive != null)
          _Prose(
            'What ${wonder.passage.bookName} stresses',
            wonder.distinctive,
            palette: palette,
            active: active == 'distinctive',
          ),

        if (wonder.reflectionQuestion != null) ...[
          const SizedBox(height: 28),
          _Spoken(
            active: active == 'reflection',
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: palette.cardGradient,
                borderRadius: BorderRadius.circular(14),
                border: const Border(
                  left: BorderSide(color: Palette.accent, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('To sit with', palette: palette),
                  const SizedBox(height: 8),
                  Text(
                    wonder.reflectionQuestion!,
                    style: GoogleFonts.merriweather(
                      fontSize: 16,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                      color: palette.shade50,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (parallels.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionTitle('Also in', palette: palette),
          const SizedBox(height: 10),
          _Spoken(
            active: active == 'parallels',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final other in parallels)
                  ActionChip(
                    label: Text(other.passage.bookName),
                    // pushReplacement, not push: walking Matthew → Mark → Luke
                    // should not build a back stack three cards deep.
                    onPressed: () =>
                        context.pushReplacement('/wonders/${other.id}'),
                  ),
              ],
            ),
          ),
        ],

        if (wonder.alsoSee.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionTitle('Read further', palette: palette),
          const SizedBox(height: 10),
          for (final ref in wonder.alsoSee)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                ref.label,
                style: TextStyle(color: palette.shade200),
              ),
            ),
        ],
      ],
    );
  }
}

/// Marks the piece of the card being spoken.
///
/// A tint rather than a border or a scroll: several of these sections already
/// carry a border of their own, and a card is short enough to keep the whole of
/// it in view without being dragged about.
class _Spoken extends StatelessWidget {
  const _Spoken({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: active
          ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: active ? Palette.accent.withValues(alpha: 0.16) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.wonder,
    required this.repo,
    required this.palette,
  });

  final Wonder wonder;
  final WondersRepository repo;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    final labels = [
      repo.labelFor(wonder.theme),
      repo.labelForEra(wonder.era),
      wonder.testament.label,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: palette.shade700.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: palette.shade100),
            ),
          ),
      ],
    );
  }
}

class _PullQuote extends StatelessWidget {
  const _PullQuote({
    required this.quote,
    required this.reference,
    required this.palette,
  });

  final String quote;
  final String reference;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: palette.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.shade600.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote,
            style: GoogleFonts.merriweather(
              fontSize: 19,
              height: 1.65,
              color: palette.shade50,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            reference,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Palette.accent,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.palette});

  final String text;
  final Palette palette;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: palette.shade300,
        ),
      );
}

class _Prose extends StatelessWidget {
  const _Prose(
    this.title,
    this.body, {
    required this.palette,
    this.active = false,
  });

  final String title;
  final String? body;
  final Palette palette;
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (body == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: _Spoken(
        active: active,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title, palette: palette),
            const SizedBox(height: 10),
            Text(
              body!,
              style: TextStyle(
                fontSize: 16,
                height: 1.65,
                color: palette.shade100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
