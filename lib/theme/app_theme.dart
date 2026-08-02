import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wonder.dart' show Testament;
import 'palette.dart';

/// Builds the two dark themes.
///
/// A note carried over from the website: both themes are dark, and the toggle
/// swaps a green mood for a blue one rather than light for dark. Flutter's
/// `Brightness.dark` is correct for both.
class AppTheme {
  const AppTheme._();

  static ThemeData of(Palette palette) {
    final scheme = ColorScheme.dark(
      primary: palette.shade300,
      onPrimary: palette.shade900,
      secondary: Palette.accent,
      onSecondary: palette.shade900,
      surface: palette.shade800,
      onSurface: palette.shade50,
      surfaceContainerHighest: palette.shade700,
      outline: palette.shade600,
    );

    // Merriweather for scripture, Inter for chrome, Playfair for titles —
    // the same three the website loads.
    final body = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.shade900,
      textTheme: body.copyWith(
        displaySmall: GoogleFonts.playfairDisplay(
          color: palette.shade50,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: GoogleFonts.playfairDisplay(
          color: palette.shade50,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.playfairDisplay(color: palette.shade50),
        bodyLarge: body.bodyLarge?.copyWith(color: palette.shade100),
        bodyMedium: body.bodyMedium?.copyWith(color: palette.shade100),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.shade900,
        foregroundColor: palette.shade50,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: palette.shade50,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.shade800,
        indicatorColor: palette.shade600,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontSize: 12, color: palette.shade100),
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.shade800,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.shade600.withValues(alpha: 0.5)),
        ),
      ),
      dividerColor: palette.shade600.withValues(alpha: 0.4),
    );
  }

  /// The reading style for scripture itself — serif, generous line height.
  /// Kept apart from [of] so the reader and the share image agree.
  static TextStyle verseStyle(Palette palette, {double fontSize = 18}) =>
      GoogleFonts.merriweather(
        color: palette.shade50,
        fontSize: fontSize,
        height: 1.7,
      );

  static Palette paletteFor(Testament testament) =>
      testament == Testament.old ? Palette.pine : Palette.ocean;
}
