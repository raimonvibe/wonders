import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../data/wonders_repository.dart';
import '../../models/wonder.dart';
import '../../providers.dart';
import '../../theme/metrics.dart';
import '../../theme/palette.dart';
import '../../theme/panel.dart';
import '../speech/speakables.dart';

/// One wonder card. The counterpart of ../../components/WonderCardBody.tsx,
/// and like it, shared by every place a card appears.
///
/// While this card is being read aloud the section being spoken is tinted and
/// kept on screen, the same way [PassageView] follows each verse. The anchors
/// come from [Speakables.card] — the two have to agree, and that is the only
/// coupling between them.
///
/// ## Why this is not a ListView
///
/// The follow-along scroll has to reach a section that is usually below the
/// fold, and a lazy `ListView` has not built those. Index-based scrolling does
/// not need the target built first — same reason the passage reader uses
/// scrollable_positioned_list.
class WonderCardBody extends ConsumerStatefulWidget {
  const WonderCardBody({
    super.key,
    required this.wonder,
    this.onReadPassage,
  });

  final Wonder wonder;

  /// Null in contexts with no passage page to move to, such as the tour.
  final VoidCallback? onReadPassage;

  /// Where in the card's section list [anchor] lands, or null when unknown.
  ///
  /// Title is spoken before anything on the card body appears, so it lands on
  /// the chips — the first thing the reader can see. Kept as a static so the
  /// order can be pinned in a test without pumping TTS.
  static int? indexOfSpokenSection(
    List<String?> sectionAnchors,
    String? anchor,
  ) {
    if (anchor == null) return null;
    final target = anchor == 'title' ? 'chips' : anchor;
    final index = sectionAnchors.indexWhere((a) => a == target);
    return index < 0 ? null : index;
  }

  @override
  ConsumerState<WonderCardBody> createState() => _WonderCardBodyState();
}

class _WonderCardBodyState extends ConsumerState<WonderCardBody> {
  final _scroll = ItemScrollController();

  /// The section we have already followed. Without it every rebuild would drag
  /// the list back to the spoken section, including the ones caused by the
  /// reader scrolling away on purpose.
  String? _followedAnchor;

  @override
  void didUpdateWidget(WonderCardBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wonder.id != widget.wonder.id) {
      _followedAnchor = null;
    }
  }

  /// Keep the section being spoken on screen, once per anchor.
  void _followSpoken(List<String?> sectionAnchors, String? anchor) {
    if (anchor == null || anchor == _followedAnchor) return;
    _followedAnchor = anchor;

    final index = WonderCardBody.indexOfSpokenSection(sectionAnchors, anchor);
    if (index == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.isAttached) return;
      _scroll.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        // A third of the way down, so the line being read has the lines it is
        // about to reach visible underneath it.
        alignment: 0.3,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final wonder = widget.wonder;
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

    final sections = _sections(
      wonder: wonder,
      repo: repo,
      palette: palette,
      parallels: parallels,
      active: active,
    );
    final sectionAnchors = [for (final s in sections) s.anchor];

    if (active != null) {
      _followSpoken(sectionAnchors, active);
    } else {
      _followedAnchor = null;
    }

    return LayoutBuilder(
      builder: (context, constraints) => ScrollablePositionedList.builder(
        itemScrollController: _scroll,
        // Same reasoning as the reader's: a card is mostly prose, and prose read
        // across the full width of a tablet runs past the length at which a line
        // is comfortable to follow. 16 is what the body copy is set at, through
        // the reader's own size — a column measured at 16 while the words are
        // painted at 26 is the same too-long line the gutter exists to prevent.
        padding: EdgeInsets.fromLTRB(
          readingGutter(
            constraints.maxWidth,
            fontSize: MediaQuery.textScalerOf(context).scale(16),
          ),
          16,
          readingGutter(
            constraints.maxWidth,
            fontSize: MediaQuery.textScalerOf(context).scale(16),
          ),
          48,
        ),
        itemCount: sections.length,
        itemBuilder: (context, index) => sections[index].child,
      ),
    );
  }

  List<_Section> _sections({
    required Wonder wonder,
    required WondersRepository repo,
    required Palette palette,
    required List<Wonder> parallels,
    required String? active,
  }) {
    final out = <_Section>[
      _Section(
        anchor: 'chips',
        child: _Spoken(
          active: active == 'chips' || active == 'title',
          child: _Chips(wonder: wonder, repo: repo, palette: palette),
        ),
      ),
    ];

    if (wonder.quote != null) {
      out.add(
        _Section(
          anchor: 'quote',
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _Spoken(
              active: active == 'quote',
              child: _PullQuote(
                quote: wonder.quote!,
                reference: wonder.quoteRef ?? wonder.passage.label,
                palette: palette,
              ),
            ),
          ),
        ),
      );
    }

    if (widget.onReadPassage != null) {
      out.add(
        _Section(
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: FilledButton.icon(
              onPressed: widget.onReadPassage,
              icon: const Icon(Icons.menu_book_outlined),
              label: Text('Read ${wonder.passage.label}'),
            ),
          ),
        ),
      );
    }

    if (wonder.location != null) {
      out.add(
        _Section(
          anchor: 'location',
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _Spoken(
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
          ),
        ),
      );
    }

    if (wonder.details.isNotEmpty) {
      out.add(
        _Section(
          anchor: 'details',
          child: Padding(
            padding: const EdgeInsets.only(top: 28),
            child: SectionLabel('Notable details', palette: palette),
          ),
        ),
      );
      for (var i = 0; i < wonder.details.length; i++) {
        out.add(
          _Section(
            anchor: 'details:$i',
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
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
          ),
        );
      }
    }

    void addProse(String title, String? body, String anchor) {
      if (body == null) return;
      out.add(
        _Section(
          anchor: anchor,
          child: Padding(
            padding: const EdgeInsets.only(top: 28),
            child: _Spoken(
              active: active == anchor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(title, palette: palette),
                  const SizedBox(height: 10),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.65,
                      color: palette.shade100,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    addProse('What happened', wonder.whatHappened, 'whatHappened');
    addProse('What it says about hope', wonder.hopeMeaning, 'hopeMeaning');

    // Rule (a) from PLAN.md: a parallel account has to say what *it*
    // stresses that the others do not, or the cards are interchangeable.
    if (wonder.distinctive != null) {
      addProse(
        'What ${wonder.passage.bookName} stresses',
        wonder.distinctive,
        'distinctive',
      );
    }

    if (wonder.reflectionQuestion != null) {
      out.add(
        _Section(
          anchor: 'reflection',
          child: Padding(
            padding: const EdgeInsets.only(top: 28),
            child: _Spoken(
              active: active == 'reflection',
              child: Panel(
                palette: palette,
                accent: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel('To sit with', palette: palette),
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
          ),
        ),
      );
    }

    if (parallels.isNotEmpty) {
      out.add(
        _Section(
          anchor: 'parallels',
          child: Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel('Also in', palette: palette),
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
            ),
          ),
        ),
      );
    }

    if (wonder.alsoSee.isNotEmpty) {
      out.add(
        _Section(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel('Read further', palette: palette),
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
            ),
          ),
        ),
      );
    }

    return out;
  }
}

class _Section {
  const _Section({this.anchor, required this.child});

  /// Matches a [SpeechChunk.anchor] from [Speakables.card], when this block
  /// is something the voice can land on.
  final String? anchor;
  final Widget child;
}

/// Marks the piece of the card being spoken.
///
/// A tint rather than a border: several of these sections already carry a
/// border of their own. The list scrolls the active section into view the same
/// way the passage reader does — tint alone was enough when every card fitted
/// on one screen; it is not, once the voice has moved past the fold.
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
    return Panel(
      palette: palette,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
