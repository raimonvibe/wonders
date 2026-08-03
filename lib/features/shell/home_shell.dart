import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../speech/speech_bar.dart';

/// The bottom-nav shell. Each destination is a StatefulShellBranch, so
/// switching tabs preserves the stack you left behind.
///
/// It also carries the speech transport, because this is the only widget that
/// outlives every navigation the app can make. A reading started on a wonder
/// card stays controllable after you cross to the Bible tab, which is the whole
/// difference between read-aloud being a feature of the app and being a feature
/// of one screen.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// One list, two shapes. `NavigationBar` and `NavigationRail` take different
  /// destination types for the same four facts, so the facts are stated once
  /// here and each bar builds its own from them.
  static const _destinations = [
    (
      icon: Icons.auto_awesome_outlined,
      selected: Icons.auto_awesome,
      label: 'Wonders',
    ),
    (
      icon: Icons.menu_book_outlined,
      selected: Icons.menu_book,
      label: 'Bible',
    ),
    (icon: Icons.route_outlined, selected: Icons.route, label: 'Tour'),
    (icon: Icons.more_horiz, selected: Icons.more_horiz, label: 'More'),
  ];

  /// Material's own compact/medium boundary.
  ///
  /// Below it a bottom bar; at it and above, a rail. The guidance is explicit
  /// that a rail is wrong under 600 and that a bottom bar wastes a medium
  /// window — and on a tablet held in landscape the bottom bar is not just
  /// wasteful but far from the hand, at the bottom edge of a screen the reader
  /// is holding by the sides.
  static const _railFrom = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Engine failures surface once, here, rather than on whichever screen
    // happened to ask — the reader does not care which one that was.
    ref.listen(speechProvider.select((s) => s.error), (_, error) {
      if (error == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    });

    final wide = MediaQuery.sizeOf(context).width >= _railFrom;

    // The transport stays along the bottom of the content in both shapes.
    // Speech is the one thing that outlives the screen that started it, so its
    // controls have to be somewhere that does the same; putting them inside the
    // rail would hide them behind a width the reader did not choose.
    final body = wide
        ? Row(
            children: [
              _Rail(shell: shell),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: shell),
                    const SpeechBar(),
                  ],
                ),
              ),
            ],
          )
        : shell;

    return Scaffold(
      body: body,
      bottomNavigationBar: wide
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SpeechBar(),
                NavigationBar(
                  selectedIndex: shell.currentIndex,
                  destinations: [
                    for (final d in _destinations)
                      NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selected),
                        label: d.label,
                      ),
                  ],
                  // initialLocation: true on a re-tap pops that branch back to
                  // its root, which is the gesture people expect from a tab bar.
                  onDestinationSelected: (index) => shell.goBranch(
                    index,
                    initialLocation: index == shell.currentIndex,
                  ),
                ),
              ],
            ),
    );
  }
}

/// The medium-window navigation.
///
/// Labelled rather than icon-only: four destinations of which two are books of
/// a sort ("Bible", "Tour") do not survive being reduced to a glyph, and the
/// rail has the room.
class _Rail extends StatelessWidget {
  const _Rail({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: shell.currentIndex,
      labelType: NavigationRailLabelType.all,
      backgroundColor: Theme.of(context).colorScheme.surface,
      destinations: [
        for (final d in HomeShell._destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selected),
            label: Text(d.label),
          ),
      ],
      onDestinationSelected: (index) => shell.goBranch(
        index,
        initialLocation: index == shell.currentIndex,
      ),
    );
  }
}
