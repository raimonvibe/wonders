import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

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
    );
  }
}
