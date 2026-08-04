import 'package:bible_wonders/features/share/share_card.dart';
import 'package:bible_wonders/models/wonder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../support/fixtures.dart';

/// ShareCard is the one widget whose exact output *is* the product: it leaves
/// the app as a PNG in someone else's feed, with no way to correct it after.
/// So it gets both kinds of test — a golden over the pixels, and assertions
/// over the content rule, which is the part that would actually matter if it
/// broke.
void main() {
  setUpAll(() {
    // Goldens must not depend on the network. Without this, google_fonts tries
    // to fetch Merriweather at paint time and the image differs between a
    // machine that has the font cached and one that does not.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Renders at the true export size, which is far larger than the default
  /// 800×600 test surface — at that size the card overflows and the golden is
  /// a stack of yellow-and-black stripes.
  Future<void> pumpCard(WidgetTester tester, Wonder wonder) async {
    tester.view.physicalSize = ShareCard.exportSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          // The card ships inside this, so it is tested inside it.
          //
          // ShareService mounts the card in the *root* overlay, which sits
          // above every Scaffold, and MaterialApp installs Flutter's
          // `_errorTextStyle` there as the DefaultTextStyle that Material
          // normally replaces — red monospace with a yellow double underline.
          // Nothing replaced it, so every line of every shared image came out
          // struck through in yellow, and this golden passed the whole time
          // because a bare MediaQuery gives `DefaultTextStyle.fallback()`,
          // which is clean.
          //
          // Reproducing the hostile style here is what makes the golden mean
          // something: remove ShareCard's own DefaultTextStyle and this test
          // fails, which is exactly what should have happened the first time.
          child: DefaultTextStyle(
            style: const TextStyle(
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFFFFFF00),
              decorationStyle: TextDecorationStyle.double,
            ),
            child: RepaintBoundary(
              child: ShareCard(wonder: wonder, siteLabel: 'bible-wonders.app'),
            ),
          ),
        ),
      ),
    );
  }

  List<String> textsOf(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();

  group('the content rule', () {
    testWidgets('puts the quote and its reference on the image',
        (tester) async {
      final wonder = testWonder();
      await pumpCard(tester, wonder);

      expect(find.text(wonder.quote!), findsOneWidget);
      expect(find.text(wonder.quoteRef!), findsOneWidget);
      expect(find.text(wonder.title), findsOneWidget);
    });

    testWidgets('keeps our prose off it', (tester) async {
      await pumpCard(tester, testWonder());

      // whatHappened, hopeMeaning and the reflection question are ours, not
      // scripture. On an image that carries a verse reference, a reader has no
      // way to tell which words are which — so none of them may appear.
      final rendered = textsOf(tester).join('\n');
      expect(
        rendered,
        isNot(contains('SECRET')),
        reason: 'card prose leaked onto the share image',
      );
    });

    testWidgets('credits the translation', (tester) async {
      await pumpCard(tester, testWonder());
      expect(find.text('World English Bible'), findsOneWidget);
      expect(find.text('bible-wonders.app'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('a long quote does not overflow the fixed canvas',
        (tester) async {
      await pumpCard(
        tester,
        testWonder(
          quote: 'And ${'the waters were divided, ' * 40}so it was.',
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders at exactly the export size', (tester) async {
      await pumpCard(tester, testWonder());
      expect(
        tester.getSize(find.byType(ShareCard)),
        ShareCard.exportSize,
      );
    });
  });

  group('goldens', () {
    // Regenerate with: flutter test --update-goldens
    testWidgets('old testament wears pine', (tester) async {
      await pumpCard(tester, testWonder());
      await expectLater(
        find.byType(ShareCard),
        matchesGoldenFile('goldens/share_card_old_testament.png'),
      );
    });

    testWidgets('new testament wears ocean', (tester) async {
      await pumpCard(
        tester,
        testWonder(
          id: 'water-into-wine',
          title: 'Water Turned to Wine at Cana',
          testament: Testament.aNew,
          quote: 'This beginning of His signs Jesus did in Cana of Galilee, '
              'and revealed His glory; and His disciples believed in Him.',
          quoteRef: 'John 2:11',
          location: 'Cana of Galilee',
        ),
      );
      await expectLater(
        find.byType(ShareCard),
        matchesGoldenFile('goldens/share_card_new_testament.png'),
      );
    });
  });
}
