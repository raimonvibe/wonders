import 'package:bible_wonders/theme/app_bar_title.dart';
import 'package:bible_wonders/theme/app_theme.dart';
import 'package:bible_wonders/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// The bar carries the name of the wonder, and on the detail screen it is the
/// *only* place that name appears. So a title that does not fit is not a
/// cosmetic fault: it is the app declining to say what you opened.
///
/// "Abimelech's Household Healed" came out as "Abimelech's Household …" at the
/// ordinary text size, before any accessibility setting was involved — a back
/// button and two actions leave 176 pt of a 360 pt phone, and twenty-eight
/// characters of Playfair do not go in it.
/// The longest title in the catalog, at 46 characters.
const _longest = "Amalek Defeated while Moses' Hands Are Held Up";

void main() {
  setUpAll(() {
    // The measurement is of a typeface, so it must not depend on whether this
    // machine has fetched one. Without this, google_fonts reaches for Playfair
    // at layout time and the answer differs between a warm cache and a cold one.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// The longest title in the catalog, at 46 characters. Checked against
  /// assets/wonders.json — if a longer one is ever added this is the test that
  /// should be updated, and the number that decides whether it still fits.
  ///
  /// A `const` at the top of `main` rather than a top-level one because the
  /// group below needs it inside a `const` widget constructor.
  const longest = _longest;

  /// A pushed screen on a 360 pt phone, which is the narrowest common Android
  /// width and therefore the case that fails first.
  Future<void> pumpBar(
    WidgetTester tester,
    String title, {
    required double scale,
    int actions = 2,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(Palette.ocean),
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: scale,
          maxScaleFactor: scale,
          child: child!,
        ),
        home: Navigator(
          // Two routes deep, so the bar draws a back button and the width
          // AppBarTitle reserves for one is the width actually taken.
          onGenerateInitialRoutes: (_, __) => [
            MaterialPageRoute<void>(builder: (_) => const SizedBox()),
            MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  toolbarHeight: AppBarTitle.toolbarHeightFor(
                    context,
                    title,
                    actions: actions,
                  ),
                  title: AppBarTitle(title, actions: actions),
                  actions: [
                    for (var i = 0; i < actions; i++)
                      const IconButton(
                        onPressed: null,
                        icon: Icon(Icons.headphones_outlined),
                      ),
                  ],
                ),
                body: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Whether the text engine had to cut the string to make it fit.
  bool wasTruncated(WidgetTester tester, String title) =>
      tester.renderObject<RenderParagraph>(find.text(title)).didExceedMaxLines;

  group('a title is never cut', () {
    // 1.0 is the plain case that was broken. 1.6 is the reading slider at its
    // maximum. 2.08 is that slider on a phone whose own font is at 1.3, which
    // is where the clamp starts doing the work.
    for (final scale in [1.0, 1.3, 1.6, 2.08]) {
      testWidgets('the one that was reported, at ${scale}x', (tester) async {
        await pumpBar(tester, "Abimelech's Household Healed", scale: scale);
        expect(wasTruncated(tester, "Abimelech's Household Healed"), isFalse);
      });

      testWidgets('the longest in the catalog, at ${scale}x', (tester) async {
        await pumpBar(tester, longest, scale: scale);
        expect(wasTruncated(tester, longest), isFalse);
      });
    }
  });

  group('the gold is never clipped', () {
    // The bug this guards: `toolbarHeightFor` estimates the title's width
    // before the bar exists to measure it. Estimate wide, and the bar is sized
    // for one line while the text takes two — the second line and its rule are
    // laid out in a box too short to hold them, and the reader gets a title
    // with its gold cut off. It reached a real screen, so it gets a real test.
    for (final scale in [1.0, 1.3, 1.6, 2.08]) {
      for (final title in [
        'Wonders and Hope',
        "The Widow's Son Raised at Zarephath",
        longest,
      ]) {
        testWidgets('${title.split(' ').first}, at ${scale}x', (tester) async {
          await pumpBar(tester, title, scale: scale);

          final bar = tester.getRect(find.byType(AppBar));
          final block = tester.getRect(find.byType(AppBarTitle));

          // Every rule the title paints lives inside its own box, so a box
          // inside the bar is gold inside the bar. The tolerance is for the
          // half-pixel the bar's vertical centring can land on.
          const slack = 0.5;
          expect(block.top, greaterThanOrEqualTo(bar.top - slack));
          expect(block.bottom, lessThanOrEqualTo(bar.bottom + slack));
        });
      }
    }
  });

  // There is deliberately no test here that a title stays inside a bar it was
  // given the wrong height for. It cannot: `AppBar` wraps its title in
  // `_AppBarTitleBox`, which lays the child out with `maxHeight: infinity` and
  // constrains only the box, so nothing inside the title can discover the bar's
  // height and clip itself to it. The title and the bar are kept in step
  // upstream instead — see `main_typefaces_test` for the last thing that put
  // them out of step, and the note in app.dart for why there is no runtime
  // safeguard under that.

  testWidgets('a short title leaves the bar exactly as it was', (tester) async {
    await pumpBar(tester, 'Genesis 1', scale: 1.0, actions: 1);
    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
  });

  testWidgets('the bar grows only as far as the title needs', (tester) async {
    await pumpBar(tester, longest, scale: 1.6);
    final height = tester.getSize(find.byType(AppBar)).height;

    expect(height, greaterThan(kToolbarHeight));
    // The ceiling AppBarTitle promises, measured rather than trusted. Only the
    // longest title in the catalog, at the largest scale a bar paints at, on a
    // narrow phone with both actions showing, gets anywhere near it.
    expect(height, lessThan(780 * 0.37));
  });

  testWidgets('the title is measured at the scale it is painted at',
      (tester) async {
    // The framework caps an app bar title at 1.34 and does it *inside* the bar,
    // where toolbarHeightFor cannot see. Measuring outside at the reader's full
    // scale while the framework painted at 1.34 is what sized a bar for two
    // lines and then put four in it, with the gold falling off the bottom.
    //
    // Both of these are above the cap, so both must come out identical — and
    // identical to what the bar reserved for them.
    await pumpBar(tester, 'Genesis 1', scale: 1.6, actions: 1);
    final atCeiling = tester.getSize(find.text('Genesis 1'));

    await pumpBar(tester, 'Genesis 1', scale: 4.0, actions: 1);
    expect(tester.getSize(find.text('Genesis 1')), atCeiling);
  });
}
