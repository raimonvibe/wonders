import 'package:flutter/material.dart';

import 'palette.dart';

/// What a screen shows when there is nothing to show.
///
/// Two of these existed and they agreed on nothing. The library centred an
/// accent icon over a heading and a sentence; the catalog dropped a bare line
/// of left-ish text a third of the way down with no icon and no heading. Both
/// are the same moment — the reader has arrived somewhere empty and needs to
/// know whether that is their doing or the app's — and an app that answers the
/// same question two different ways makes the reader wonder which screen is
/// broken.
///
/// [title] is the answer in one line. [body] is what to do about it, if there
/// is anything. [action] is the doing of it, when one tap can.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.icon,
    this.body,
    this.action,
  });

  final String title;
  final IconData? icon;
  final String? body;
  final Widget? action;

  static const _padding = EdgeInsets.fromLTRB(32, 40, 32, 40);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 40, color: Palette.accent),
          const SizedBox(height: 16),
        ],
        Text(
          title,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    );

    // Where this lands decides how it has to behave. Inside an `Expanded` the
    // height is bounded, and a plain Column overflows the moment the reader
    // turns their text size up; inside a sliver it is unbounded, where a scroll
    // view throws outright. Asking is cheaper than having two of these.
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: constraints.hasBoundedHeight
            ? SingleChildScrollView(padding: _padding, child: column)
            : Padding(padding: _padding, child: column),
      ),
    );
  }
}

/// The wait, said out loud.
///
/// Four screens each centred a bare `CircularProgressIndicator`, which is
/// silent to a screen reader — TalkBack announces nothing at all while the
/// Bible database opens, so a reader who cannot see the spinner cannot tell a
/// slow first launch from a dead screen. That is the reader this app spends
/// most of its code on.
class Loading extends StatelessWidget {
  const Loading(this.label, {super.key});

  /// What is being waited for, as a sentence: "Opening the Bible".
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: CircularProgressIndicator(semanticsLabel: label),
      );
}
