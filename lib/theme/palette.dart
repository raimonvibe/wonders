import 'package:flutter/material.dart';

/// The palettes the app can wear.
///
/// Pine and ocean are lifted from ../../tailwind.config.js so the app and the
/// website stay the same colour. Cedar is app-only: the brown linear gradient
/// from `#6B4223` down to `#4A2E18`. All three are dark. Pine is the Old
/// Testament green, ocean the New Testament blue, cedar a pinned brown.
///
/// Polarity matches Tailwind's: 50 is the lightest (reading text), 900 the
/// deepest (page ground).
class Palette {
  const Palette._({
    required this.id,
    required this.label,
    required this.shade50,
    required this.shade100,
    required this.shade200,
    required this.shade300,
    required this.shade400,
    required this.shade500,
    required this.shade600,
    required this.shade700,
    required this.shade800,
    required this.shade900,
  });

  /// What settings and prefs store. Stable; do not rename.
  final String id;

  /// The name on the More tab: Green, Blue, Brown.
  final String label;

  final Color shade50;
  final Color shade100;
  final Color shade200;
  final Color shade300;
  final Color shade400;
  final Color shade500;
  final Color shade600;
  final Color shade700;
  final Color shade800;
  final Color shade900;

  /// Old Testament green.
  static const pine = Palette._(
    id: 'pine',
    label: 'Green',
    shade50: Color(0xFFEAF6F0),
    shade100: Color(0xFFCFE9DC),
    shade200: Color(0xFFA9D6C1),
    shade300: Color(0xFF7CBFA1),
    shade400: Color(0xFF52A381),
    shade500: Color(0xFF358566),
    shade600: Color(0xFF2A6B52),
    shade700: Color(0xFF1D4D3A),
    shade800: Color(0xFF163D2F),
    shade900: Color(0xFF0E2A20),
  );

  /// New Testament blue.
  static const ocean = Palette._(
    id: 'ocean',
    label: 'Blue',
    shade50: Color(0xFFEAF2FB),
    shade100: Color(0xFFD0E3F6),
    shade200: Color(0xFFA8CAEC),
    shade300: Color(0xFF79ACE0),
    shade400: Color(0xFF4A8BD0),
    shade500: Color(0xFF2A70B8),
    shade600: Color(0xFF1A5A9E),
    shade700: Color(0xFF0A3D6B),
    shade800: Color(0xFF062A4A),
    shade900: Color(0xFF041D33),
  );

  /// Pinned brown. The page ground is the linear gradient between the two
  /// colours that define it: `#6B4223` at the top, `#4A2E18` at the foot.
  static const cedar = Palette._(
    id: 'cedar',
    label: 'Brown',
    shade50: Color(0xFFF6EDE4),
    shade100: Color(0xFFE9D6C4),
    shade200: Color(0xFFD4B496),
    shade300: Color(0xFFC7A48A),
    shade400: Color(0xFFBD9475),
    shade500: Color(0xFF8F5E32),
    shade600: Color(0xFF7A4C29),
    shade700: Color(0xFF6B4223),
    shade800: Color(0xFF5A381E),
    shade900: Color(0xFF4A2E18),
  );

  /// Every palette a reader can pin. Follow is the absence of a pin, not a
  /// fourth entry: it wears [pine] or [ocean] according to the testament.
  static const values = [pine, ocean, cedar];

  /// The lock stored in prefs, or null for Follow.
  ///
  /// `old` and `new` are the ids this used to store when a pin was a testament
  /// rather than a palette. They still resolve, so a reader who pinned Green
  /// or Blue before cedar existed keeps the colour they chose.
  static Palette? lockedOf(String? id) => switch (id) {
        'pine' || 'old' => pine,
        'ocean' || 'new' => ocean,
        'cedar' => cedar,
        _ => null,
      };

  /// Green on the left, blue on the right — the Follow chip's preview, so the
  /// control that means "both" actually shows both.
  static const followPreview = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF1D4D3A), Color(0xFF0A3D6B)],
  );

  /// Used sparingly for highlights and focus, in every theme.
  static const accent = Color(0xFFF4A261);

  /// Old gold, and the one flat value to reach for when a gradient will not do.
  ///
  /// Flutter has no `Colors.gold` — the Material palette stops at amber — and
  /// CSS's own `gold`, #FFD700, is the wrong gold for this app: at full
  /// saturation on shade900 it reads as a warning colour rather than as gilt.
  /// This is that hue pulled back and warmed, which is what a gilded edge
  /// actually looks like.
  static const gold = Color(0xFFE7C766);

  /// Gold as a struck metal rather than as a colour.
  ///
  /// A single value cannot look metallic: what the eye reads as metal is the
  /// travelling highlight, a bright band with the surface falling away to a
  /// darker tone either side of it. So the rule under a title is painted with
  /// this rather than filled with [gold] — six stops, the glint off centre
  /// because a highlight dead in the middle reads as a symmetrical graphic and
  /// not as light landing on something.
  ///
  /// Chosen against every shade900 ground, including cedar's `#4A2E18`, which
  /// is the lightest this app ever gets and the hardest test of a warm colour
  /// against brown. The three light stops clear 7:1 against any of them.
  static const goldSheen = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF8A6A1C), // the shadowed edge
      Color(0xFFD9B44A),
      Color(0xFFFFF0B8), // the glint
      Color(0xFFE7C766),
      Color(0xFFC08E2A),
      Color(0xFF8A6A1C),
    ],
    stops: [0.0, 0.30, 0.46, 0.60, 0.85, 1.0],
  );

  /// The page ground: `bg-theme-pine` / `bg-theme-ocean` in Tailwind, and the
  /// same three-stop fall for cedar.
  LinearGradient get pageGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [shade700, shade800, shade900],
        stops: const [0.0, 0.55, 1.0],
      );

  /// The card surface: `bg-card-pine` / `bg-card-ocean`.
  LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          shade700.withValues(alpha: 0.92),
          shade800.withValues(alpha: 0.90),
          shade900.withValues(alpha: 0.94),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  @override
  bool operator ==(Object other) => other is Palette && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
