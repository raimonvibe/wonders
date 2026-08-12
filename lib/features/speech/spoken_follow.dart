import 'package:flutter/widgets.dart';

/// Bring the widget for [key] into view while speech is following along.
///
/// Used by the home list and the book grid — places that are not already a
/// [ScrollablePositionedList]. No-ops when the key has not been built yet
/// (off-screen lazy children); the caller can nudge the scroll first.
Future<void> ensureSpokenVisible(GlobalKey key) async {
  final context = key.currentContext;
  if (context == null) return;
  await Scrollable.ensureVisible(
    context,
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOut,
    alignment: 0.3,
  );
}
