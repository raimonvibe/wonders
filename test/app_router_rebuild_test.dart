import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Why there is no `systemFonts` listener in [BibleWondersApp].
///
/// The app computes a good deal from text metrics and has to — the grids'
/// extents, the reading gutter, the path chips' arrangement, every app bar's
/// height. A font arriving invalidates all of it without rebuilding anything:
/// the framework notifies `PaintingBinding.systemFonts`, every
/// `RenderParagraph` marks itself dirty and lays out again, and no widget's
/// `build` runs.
///
/// The obvious remedy is for the widget that owns `MaterialApp.router` to
/// listen and `setState`. This is that remedy, measured. It does not work, and
/// the failure is silent, which is the kind worth pinning down in a test rather
/// than rediscovering: a listener would have been a comfort that did nothing,
/// and the real fix — waiting for the faces in `main` before the first frame —
/// would have looked redundant beside it.
void main() {
  testWidgets('a setState above MaterialApp.router does not rebuild a screen',
      (tester) async {
    var screenBuilds = 0;
    late void Function() rebuildTheApp;

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            screenBuilds++;
            return const Scaffold(body: Text('home'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      _App(register: (fn) => rebuildTheApp = fn, router: router),
    );
    await tester.pumpAndSettle();
    expect(screenBuilds, 1);

    rebuildTheApp();
    await tester.pumpAndSettle();

    // GoRouter serves the page it already built. If this ever starts failing,
    // GoRouter has changed how it caches pages — and the note in app.dart about
    // why the listener was left out should be revisited along with it.
    expect(
      screenBuilds,
      1,
      reason: 'the route builder re-ran, so an app-level rebuild now does '
          'reach the screens',
    );
  });
}

/// Shaped like [BibleWondersApp]: the `MaterialApp.router` is constructed
/// inside `build`, so a `setState` really does make a fresh one.
class _App extends StatefulWidget {
  const _App({required this.register, required this.router});

  final void Function(void Function()) register;
  final GoRouter router;

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  @override
  void initState() {
    super.initState();
    widget.register(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) =>
      MaterialApp.router(routerConfig: widget.router);
}
