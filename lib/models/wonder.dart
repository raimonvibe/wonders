import 'passage_ref.dart';

/// Which testament a wonder belongs to. Also decides the theme the app wears
/// while you are reading it — see AppTheme.
enum Testament {
  old('old'),
  aNew('new');

  const Testament(this.id);
  final String id;

  static Testament parse(String id) =>
      values.firstWhere((t) => t.id == id, orElse: () => Testament.old);

  String get label => this == Testament.old ? 'Old Testament' : 'New Testament';
}

/// Coarse grouping for the "By theme" reading path.
///
/// Named WonderTheme because `Theme` is a Flutter widget. The ids must stay in
/// step with `Theme` in ../../lib/wonders/types.ts — scripts/export-wonders.js
/// fails the build if the catalog grows a value that is missing here.
enum WonderTheme {
  healing('healing'),
  raising('raising'),
  nature('nature'),
  provision('provision'),
  rescue('rescue'),
  judgment('judgment'),
  sign('sign');

  const WonderTheme(this.id);
  final String id;

  static WonderTheme parse(String id) =>
      values.firstWhere((t) => t.id == id, orElse: () => WonderTheme.sign);
}

/// Coarse grouping for the "By book or era" reading path. Old Testament eras
/// are spans; the New Testament is split by book, because the same event told
/// by Matthew and by Luke are two separate wonders here.
enum WonderEra {
  torah('torah'),
  conquest('conquest'),
  kingdoms('kingdoms'),
  prophets('prophets'),
  exile('exile'),
  matthew('matthew'),
  mark('mark'),
  luke('luke'),
  john('john'),
  acts('acts');

  const WonderEra(this.id);
  final String id;

  static WonderEra parse(String id) =>
      values.firstWhere((e) => e.id == id, orElse: () => WonderEra.torah);
}

/// One wonder in the catalog.
///
/// The prose fields are written in ../../lib/wonders/ and validated there —
/// `npm run validate:wonders` is what proves every [quote] appears verbatim in
/// the verses [quoteRef] names. Nothing about a passage is written here.
class Wonder {
  const Wonder({
    required this.id,
    required this.title,
    required this.testament,
    required this.passage,
    required this.theme,
    required this.era,
    required this.authored,
    this.parallelGroupId,
    this.familiarityRank,
    this.location,
    this.quote,
    this.quoteRef,
    this.details = const [],
    this.whatHappened,
    this.hopeMeaning,
    this.reflectionQuestion,
    this.distinctive,
    this.alsoSee = const [],
  });

  factory Wonder.fromJson(Map<String, dynamic> json) {
    return Wonder(
      id: json['id'] as String,
      title: json['title'] as String,
      testament: Testament.parse(json['testament'] as String),
      passage: PassageRef.fromJson(json['passage'] as Map<String, dynamic>),
      theme: WonderTheme.parse(json['theme'] as String),
      era: WonderEra.parse(json['era'] as String),
      authored: json['authored'] as bool? ?? false,
      parallelGroupId: json['parallelGroupId'] as String?,
      familiarityRank: (json['familiarityRank'] as num?)?.toInt(),
      location: json['location'] as String?,
      quote: json['quote'] as String?,
      quoteRef: json['quoteRef'] as String?,
      details:
          (json['details'] as List<dynamic>?)?.cast<String>() ?? const [],
      whatHappened: json['whatHappened'] as String?,
      hopeMeaning: json['hopeMeaning'] as String?,
      reflectionQuestion: json['reflectionQuestion'] as String?,
      distinctive: json['distinctive'] as String?,
      alsoSee: (json['alsoSee'] as List<dynamic>?)
              ?.map((e) => PassageRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Stable kebab-case id; for parallels, suffixed with the book (`-mat`).
  final String id;
  final String title;
  final Testament testament;
  final PassageRef passage;
  final WonderTheme theme;
  final WonderEra era;

  /// Whether the card prose is written, as opposed to an index-only stub.
  final bool authored;

  /// Accounts of the same event share this, so each card can offer
  /// "Also in Matthew · Luke" links. Null when an event is told only once.
  final String? parallelGroupId;

  /// Curator-defined, lower = better known. Drives the best-known sort and the
  /// Start Here shortlist. Null means "not ranked".
  final int? familiarityRank;

  final String? location;

  /// Verbatim WEB quotation used as the pull quote. This, with [quoteRef], is
  /// the only text allowed onto a share image — see share/share_card.dart.
  final String? quote;
  final String? quoteRef;

  final List<String> details;
  final String? whatHappened;
  final String? hopeMeaning;
  final String? reflectionQuestion;

  /// For Gospel parallels: what *this* account stresses that the others do not.
  final String? distinctive;

  final List<PassageRef> alsoSee;

  bool get hasParallels => parallelGroupId != null;
  bool get isRanked => familiarityRank != null;
  bool get isShareable => quote != null && quoteRef != null;
}
