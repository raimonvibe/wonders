import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/metrics.dart';

/// What the app calls itself, and which build it is.
///
/// Both are shown on the licences page, and the version is the one thing here
/// that can silently stop being true: pubspec.yaml is where it is really set,
/// and a copy of a number is a copy that drifts. `app_version_test` reads the
/// pubspec and fails if these two disagree, which is cheaper than a dependency
/// that reads the version off the platform at runtime for one line of text.
const appName = 'Wonders and Hope';
const appVersion = '1.0.0';

class BibleWondersApp extends ConsumerStatefulWidget {
  const BibleWondersApp({super.key});

  @override
  ConsumerState<BibleWondersApp> createState() => _BibleWondersAppState();
}

class _BibleWondersAppState extends ConsumerState<BibleWondersApp> {
  late final GoRouter _router = AppRouter.build();

  @override
  Widget build(BuildContext context) {
    // The palette is app-wide state, not a per-screen decision: it changes as
    // the reader crosses from the Old Testament into the New, and the whole
    // app follows.
    final palette = ref.watch(themeProvider);

    // Watched here rather than inside the builder below: the builder runs as
    // part of a descendant's build, and a provider has to be watched from the
    // build of the widget that depends on it.
    final reading = ref.watch(fontScaleProvider);

    // MaterialApp already wraps its subtree in an AnimatedTheme, so the
    // crossfade is configured here rather than by wrapping it — a wrapping
    // AnimatedTheme sits above MaterialApp and loses to the theme MaterialApp
    // installs for its own descendants.
    return MaterialApp.router(
      title: 'Wonders and Hope',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(palette),
      themeAnimationDuration: const Duration(milliseconds: 450),
      themeAnimationCurve: Curves.easeOut,
      routerConfig: _router,
      // The reading size, for the whole app and once. Inside MaterialApp so it
      // sits above every route but below the MediaQuery the platform installs,
      // which is the one it composes with. See [ReadingScaler].
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: ReadingScaler(
            MediaQuery.textScalerOf(context),
            reading,
          ),
        ),
        child: child!,
      ),
    );
  }
}
