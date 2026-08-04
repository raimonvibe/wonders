import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bible.dart';
import '../../models/wonder.dart';
import '../../providers.dart';
import '../bible/passage_view.dart';
import '../share/share_service.dart';
import '../speech/listen_button.dart';
import '../speech/speakables.dart';
import '../speech/speech_chunk.dart';
import '../speech/speech_controller.dart' show SpeechReach;
import 'wonder_card_body.dart';

enum WonderDetailPage { card, passage }

/// A wonder, as two pages you swipe between.
///
/// This is the phone translation of the website's 50/50 dock. There, the card
/// and its chapter sit side by side; here they are one horizontal swipe apart,
/// which keeps the same promise — read the passage, not just about it — on a
/// screen that can only show one column.
///
/// Both pages live in the Wonders branch of the shell. The reader never
/// changes tabs to follow a card into scripture, so the Bible tab keeps
/// whatever chapter it was left on and the back button still returns to the
/// list the card came from.
class WonderDetailScreen extends ConsumerStatefulWidget {
  const WonderDetailScreen({
    super.key,
    required this.wonderId,
    this.initialPage = WonderDetailPage.card,
  });

  final String wonderId;
  final WonderDetailPage initialPage;

  @override
  ConsumerState<WonderDetailScreen> createState() => _WonderDetailScreenState();
}

class _WonderDetailScreenState extends ConsumerState<WonderDetailScreen> {
  late final PageController _pages =
      PageController(initialPage: widget.initialPage.index);
  late int _page = widget.initialPage.index;

  @override
  void initState() {
    super.initState();

    // Two side effects, both deferred until after the first frame so they
    // never fight the build: remember this card for "continue where you left
    // off", and let the app take on the testament's palette.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wonder = ref.read(wondersProvider).byId(widget.wonderId);
      if (wonder == null || !mounted) return;
      ref.read(lastWonderProvider.notifier).set(wonder.id);
      ref.read(themeProvider.notifier).followTestament(wonder.testament);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(WonderDetailPage page) => _pages.animateToPage(
        page.index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );

  /* --- read aloud --------------------------------------------------------- */
  //
  // The page you are looking at decides what gets read; the reach setting only
  // decides how far a reading started from the card goes. Anything else means
  // swiping to the passage and pressing Listen reads the card instead, which
  // nobody would expect.

  bool get _onPassage => _page == WonderDetailPage.passage.index;

  String _sourceId(Wonder wonder) {
    if (_onPassage) return Speakables.chapterKey(wonder.passage.chapterId);
    return switch (ref.watch(speechProvider).reach) {
      SpeechReach.card => Speakables.cardId(wonder),
      SpeechReach.passage => Speakables.chapterKey(wonder.passage.chapterId),
      SpeechReach.both => Speakables.bothId(wonder),
    };
  }

  Future<Speakable?> _buildSpeakable(Wonder wonder) async {
    final repo = ref.read(wondersProvider);
    final reach =
        _onPassage ? SpeechReach.passage : ref.read(speechProvider).reach;

    // The card alone needs nothing from the database, so do not open it.
    if (reach == SpeechReach.card) return Speakables.card(wonder, repo);

    final bible = ref.read(bibleProvider);
    final chapterId = wonder.passage.chapterId;
    final Chapter? chapter = await bible.chapter(chapterId);
    final verses =
        chapter == null ? const <Verse>[] : await bible.versesIn(chapterId);

    return Speakables.forReach(
      reach,
      wonder: wonder,
      repo: repo,
      chapter: chapter,
      verses: verses,
    );
  }

  /// Where a reading of this wonder's chapter should begin.
  ///
  /// "Both" walks the card first, so it is already in the right place; the
  /// other two start on the verse the card cites rather than at verse 1.
  int _startAt(Wonder wonder, Speakable source) {
    if (source.id == Speakables.bothId(wonder)) return 0;
    if (source.id == Speakables.cardId(wonder)) return 0;
    return Speakables.startOf(source, wonder.passage);
  }

  @override
  Widget build(BuildContext context) {
    final wonder = ref.watch(wondersProvider).byId(widget.wonderId);
    final palette = ref.watch(themeProvider);

    if (wonder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not found')),
        body:
            Center(child: Text('No wonder with the id "${widget.wonderId}".')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_onPassage ? wonder.passage.label : wonder.title),
        actions: [
          ListenButton(
            sourceId: _sourceId(wonder),
            source: () => _buildSpeakable(wonder),
            from: (source) => _startAt(wonder, source),
            tooltip: _onPassage ? 'Read the passage aloud' : 'Read this aloud',
          ),
          if (wonder.isShareable)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Share the quote',
              onPressed: () => _share(context, wonder),
            ),
        ],
        // A two-dot indicator doubles as the control: tap either side to move,
        // or swipe the body.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _PageSwitch(
            page: _page,
            onSelect: (page) => _goTo(WonderDetailPage.values[page]),
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.pageGradient),
        child: PageView(
          controller: _pages,
          onPageChanged: (page) => setState(() => _page = page),
          children: [
            WonderCardBody(
              wonder: wonder,
              onReadPassage: () => _goTo(WonderDetailPage.passage),
            ),
            PassageView(
              chapterId: wonder.passage.chapterId,
              highlight: wonder.passage,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, Wonder wonder) async {
    const service = ShareService(
      siteLabel: 'Play Store App “Wonders”',
      // The listing itself. Fixed by the applicationId, so this is the address
      // for the life of the app and never needs revisiting — see
      // ShareService.link for the one period where it does not resolve.
      link:
          'https://play.google.com/store/apps/details?id=com.raimonvibe.wonders',
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.shareWonder(context, wonder);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not build the image: $error')),
      );
    }
  }
}

/// The card / passage switch. Labelled rather than dotted, because on first
/// use nobody knows there is a second page to swipe to.
class _PageSwitch extends StatelessWidget {
  const _PageSwitch({required this.page, required this.onSelect});

  final int page;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('The card')),
          ButtonSegment(value: 1, label: Text('The passage')),
        ],
        selected: {page},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onSelect(selection.first),
      ),
    );
  }
}
