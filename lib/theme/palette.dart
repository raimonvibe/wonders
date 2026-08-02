import 'package:flutter/material.dart';

/// The two palettes, lifted from ../../tailwind.config.js so the app and the
/// website stay the same colour. Both are dark: pine is the Old Testament
/// green, ocean the New Testament blue.
///
/// Polarity matches Tailwind's: 50 is the lightest (reading text), 900 the
/// deepest (page ground).
class Palette {
  const Palette._({
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

  /// Used sparingly for highlights and focus, in both themes.
  static const accent = Color(0xFFF4A261);

  /// The page ground: `bg-theme-pine` / `bg-theme-ocean` in Tailwind.
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
}
