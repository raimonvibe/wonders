import 'package:bible_wonders/features/bible/reader_screen.dart';
import 'package:bible_wonders/models/bible.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bar under the reader has half a phone per reference and no say in how
/// long a book's name is. "1 Thessalonians" is the worst case in the canon, and
/// a reader on the one screen that exists for reading is the reader most likely
/// to have turned their text size up.
void main() {
  Chapter chapter(String reference) => Chapter(
        id: 'X.1',
        bookId: 'X',
        number: '1',
        reference: reference,
        sortOrder: 1,
        verseCount: 10,
      );

  Future<void> pumpBar(
    WidgetTester tester, {
    Chapter? previous,
    Chapter? next,
    double textScale = 1.0,
    void Function(Chapter)? onGo,
  }) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            bottomNavigationBar: ChapterTurnBar(
              previous: previous,
              next: next,
              onGo: onGo ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final scale in [1.0, 1.3, 1.6]) {
    testWidgets('the longest book names fit at ${scale}x text', (tester) async {
      await pumpBar(
        tester,
        previous: chapter('1 Thessalonians 5'),
        next: chapter('2 Thessalonians 1'),
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an end of the Bible shows nothing rather than a dead chevron',
      (tester) async {
    await pumpBar(tester, previous: null, next: chapter('Genesis 2'));

    expect(find.text('Genesis 2'), findsOneWidget);
    expect(
      find.byIcon(Icons.chevron_left),
      findsNothing,
      reason: 'a disabled chevron with no label reads as a broken button',
    );
  });

  testWidgets('either end turns the page', (tester) async {
    final turns = <String>[];
    await pumpBar(
      tester,
      previous: chapter('Exodus 13'),
      next: chapter('Exodus 15'),
      onGo: (c) => turns.add(c.reference),
    );

    await tester.tap(find.text('Exodus 13'));
    await tester.tap(find.text('Exodus 15'));
    expect(turns, ['Exodus 13', 'Exodus 15']);
  });
}
