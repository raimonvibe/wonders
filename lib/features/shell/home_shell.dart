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

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.auto_awesome_outlined),
      selectedIcon: Icon(Icons.auto_awesome),
      label: 'Wonders',
    ),
    NavigationDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book),
      label: 'Bible',
    ),
    NavigationDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route),
      label: 'Tour',
    ),
    NavigationDestination(
      icon: Icon(Icons.more_horiz),
      label: 'More',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Engine failures surface once, here, rather than on whichever screen
    // happened to ask — the reader does not care which one that was.
    ref.listen(speechProvider.select((s) => s.error), (_, error) {
      if (error == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    });

    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SpeechBar(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            destinations: _destinations,
            // initialLocation: true on a re-tap pops that branch back to its
            // root, which is the gesture people expect from a tab bar.
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
