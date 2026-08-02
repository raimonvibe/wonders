import '../../data/reading_paths.dart';
import '../../data/wonders_repository.dart';
import '../../models/bible.dart';
import '../../models/passage_ref.dart';
import '../../models/wonder.dart';
import 'speech_chunk.dart';
import 'speech_controller.dart' show SpeechReach;

/// How each screen turns into speech.
///
/// The one place that knows what "read this aloud" means for a wonder, a
/// chapter or a list. Keeping it here rather than in the screens is what lets
/// the tour and the wonder card read the same card the same way, and it is the
/// Dart answer to ../../lib/readAloud.ts walking the DOM.
class Speakables {
  const Speakables._();

  /* --- ids ---------------------------------------------------------------- */
  //
  // Content-derived, not instance-derived: a rebuilt screen must produce the
  // same id or the Listen button stops recognising its own material.

  static String cardId(Wonder wonder) => 'card:${wonder.id}';
  static String chapterKey(String chapterId) => 'chapter:$chapterId';
  static String bothId(Wonder wonder) => 'both:${wonder.id}';
  static const wondersListId = 'list:wonders';
  static const booksId = 'list:books';
  static String chaptersId(String bookId) => 'list:chapters:$bookId';
  static const aboutId = 'about';

  /// The anchor a chapter's verse carries, so [PassageView] can mark the line
  /// being spoken and a wonder's passage can start on the verse it cites.
  static String verseAnchor(String chapterId, int number) =>
      'verse:$chapterId:$number';

  /* --- a wonder card ------------------------------------------------------ */

  /// One wonder's card, in the order it is laid out on screen.
  ///
  /// The anchors match the section names WonderCardBody uses, so the section
  /// being spoken can be tinted as it goes.
  static Speakable card(Wonder wonder, WondersRepository repo) {
    final chunks = <SpeechChunk>[
      SpeechChunk(wonder.title, anchor: 'title', label: wonder.title),
      SpeechChunk(
        '${repo.labelFor(wonder.theme)}. '
        '${repo.labelForEra(wonder.era)}. '
        '${wonder.testament.label}.',
        anchor: 'chips',
      ),
    ];

    if (wonder.quote != null) {
      // The reference is spoken after the quote, not before, so the words of
      // scripture are not preceded by a string of numbers.
      chunks.add(
        SpeechChunk(
          '${wonder.quote!} ${wonder.quoteRef ?? wonder.passage.label}.',
          anchor: 'quote',
          label: wonder.quoteRef ?? wonder.passage.label,
        ),
      );
    }

    if (wonder.location != null) {
      chunks.add(SpeechChunk('Where: ${wonder.location!}.', anchor: 'location'));
    }

    if (wonder.details.isNotEmpty) {
      chunks.add(const SpeechChunk('Notable details.', anchor: 'details'));
      for (var i = 0; i < wonder.details.length; i++) {
        chunks.add(SpeechChunk(wonder.details[i], anchor: 'details:$i'));
      }
    }

    _addProse(chunks, 'What happened.', wonder.whatHappened, 'whatHappened');
    _addProse(
      chunks,
      'What it says about hope.',
      wonder.hopeMeaning,
      'hopeMeaning',
    );
    _addProse(
      chunks,
      'What ${wonder.passage.bookName} stresses.',
      wonder.distinctive,
      'distinctive',
    );
    _addProse(chunks, 'To sit with.', wonder.reflectionQuestion, 'reflection');

    final parallels = repo.parallelsOf(wonder);
    if (parallels.isNotEmpty) {
      chunks.add(
        SpeechChunk(
          'Also told in '
          '${_list(parallels.map((w) => w.passage.bookName).toList())}.',
          anchor: 'parallels',
        ),
      );
    }

    return Speakable(id: cardId(wonder), title: wonder.title, chunks: chunks);
  }

  /// A heading and its paragraph, as two chunks.
  ///
  /// Two rather than one because the heading is the natural place for a skip to
  /// land, and because a heading run into the prose behind it sounds like a
  /// sentence that lost its verb.
  static void _addProse(
    List<SpeechChunk> chunks,
    String heading,
    String? body,
    String anchor,
  ) {
    if (body == null || body.trim().isEmpty) return;
    chunks.add(SpeechChunk(heading, anchor: anchor));
    chunks.add(SpeechChunk(body, anchor: anchor));
  }

  /* --- scripture ---------------------------------------------------------- */

  /// A chapter, one verse per chunk.
  ///
  /// Verse numbers are not spoken. They are on screen, they break the sense of
  /// every sentence that runs across a verse boundary, and the website does not
  /// speak them either — `.verse-num` is stripped before the text is read.
  static Speakable chapter(Chapter chapter, List<Verse> verses) {
    return Speakable(
      id: chapterKey(chapter.id),
      title: chapter.reference,
      chunks: [
        SpeechChunk(chapter.reference, label: chapter.reference),
        for (final verse in verses)
          SpeechChunk(
            verse.text,
            anchor: verseAnchor(chapter.id, verse.number),
            label: '${chapter.reference}:${verse.number}',
          ),
      ],
    );
  }

  /// The chunk a chapter should start on when the reader arrived from a card.
  ///
  /// Reading Exodus 14 from verse 1 when the card sent you to verse 21 is the
  /// audio version of landing above the fold — it sounds like the link did
  /// nothing. Falls back to the beginning when the verse is not in the queue.
  static int startOf(Speakable speakable, PassageRef? highlight) {
    if (highlight == null) return 0;
    final index = speakable.indexOfAnchor(
      verseAnchor(highlight.chapterId, highlight.firstVerse),
    );
    return index < 0 ? 0 : index;
  }

  /* --- a wonder and its passage together ---------------------------------- */

  /// The card, then the chapter it happened in — the website's "Both".
  static Speakable cardAndPassage({
    required Wonder wonder,
    required WondersRepository repo,
    required Chapter chapter,
    required List<Verse> verses,
  }) {
    final cardPart = card(wonder, repo);
    final passagePart = Speakables.chapter(chapter, verses);
    return Speakable(
      id: bothId(wonder),
      title: wonder.title,
      chunks: [
        ...cardPart.chunks,
        const SpeechChunk('Now the passage.'),
        // Drop the passage's own title chunk: it would say the reference again
        // one sentence after the line above.
        ...passagePart.chunks.skip(1),
      ],
    );
  }

  /// What [SpeechReach] asks for, given the pieces. Returns null when the reach
  /// needs a passage that could not be loaded.
  static Speakable? forReach(
    SpeechReach reach, {
    required Wonder wonder,
    required WondersRepository repo,
    Chapter? chapter,
    List<Verse> verses = const [],
  }) {
    switch (reach) {
      case SpeechReach.card:
        return card(wonder, repo);
      case SpeechReach.passage:
        if (chapter == null || verses.isEmpty) return null;
        return Speakables.chapter(chapter, verses);
      case SpeechReach.both:
        // A card with no passage still reads as a card; refusing outright would
        // punish the reader for a database miss they cannot see.
        if (chapter == null || verses.isEmpty) return card(wonder, repo);
        return cardAndPassage(
          wonder: wonder,
          repo: repo,
          chapter: chapter,
          verses: verses,
        );
    }
  }

  /* --- the lists ---------------------------------------------------------- */

  /// The Wonders home, read the way the page reads: what it is, which path is
  /// in force, then the wonders that path resolves to.
  static Speakable wondersList({
    required int catalogCount,
    required PathState path,
    required List<Wonder> wonders,
  }) {
    return Speakable(
      id: wondersListId,
      title: 'Wonders and Hope',
      chunks: [
        SpeechChunk(
          'Wonders and Hope. $catalogCount wonders, each with the passage it '
          'happened in.',
          anchor: 'intro',
        ),
        SpeechChunk('${path.path.label}. ${path.path.blurb}', anchor: 'path'),
        if (wonders.isEmpty)
          const SpeechChunk('Nothing on this path matches.')
        else
          SpeechChunk(
            wonders.length == 1 ? '1 wonder.' : '${wonders.length} wonders.',
          ),
        for (final wonder in wonders)
          SpeechChunk(
            '${wonder.title}. ${wonder.passage.label}.',
            anchor: 'wonder:${wonder.id}',
            label: wonder.title,
          ),
      ],
    );
  }

  /// The 66 books, by testament, with how many chapters each has.
  static Speakable books(List<Book> books) {
    final old = books.where((b) => b.testament == Testament.old).toList();
    final current = books.where((b) => b.testament == Testament.aNew).toList();

    SpeechChunk chunkFor(Book book) => SpeechChunk(
          '${book.name}, ${book.chapterCount} '
          '${book.chapterCount == 1 ? 'chapter' : 'chapters'}.',
          anchor: 'book:${book.id}',
          label: book.name,
        );

    return Speakable(
      id: booksId,
      title: 'The Bible',
      chunks: [
        SpeechChunk('Old Testament, ${old.length} books.'),
        ...old.map(chunkFor),
        SpeechChunk('New Testament, ${current.length} books.'),
        ...current.map(chunkFor),
      ],
    );
  }

  /// A book's chapter grid. Reading fifty numbers one by one would be a minute
  /// of counting, so this says what is there and leaves the choosing to the eye.
  static Speakable chapterList(Book book, List<Chapter> chapters) {
    return Speakable(
      id: chaptersId(book.id),
      title: book.name,
      chunks: [
        SpeechChunk(
          '${book.name}. ${chapters.length} '
          '${chapters.length == 1 ? 'chapter' : 'chapters'}. '
          'Choose one to begin reading.',
        ),
      ],
    );
  }

  /// The More tab, so the page that explains the app can also be heard.
  static Speakable about({required int wonderCount}) {
    return Speakable(
      id: aboutId,
      title: 'About',
      chunks: [
        const SpeechChunk(
          'The scripture in this app is the World English Bible, which is in '
          'the public domain. The whole text ships with the app, so nothing '
          'here needs a connection.',
          anchor: 'web',
        ),
        SpeechChunk(
          '$wonderCount wonder cards, each checked against the passage it '
          'cites.',
          anchor: 'wonders',
        ),
      ],
    );
  }

  /// "Matthew, Mark and Luke".
  static String _list(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
  }
}
