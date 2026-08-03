import 'package:bible_wonders/app.dart';
import 'package:bible_wonders/features/settings/licenses_tile.dart';
import 'package:bible_wonders/main.dart' show bundleTheTypefaces;
import 'package:bible_wonders/theme/app_theme.dart';
import 'package:bible_wonders/theme/palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The licences have to be reachable, not merely present.
///
/// They were registered into `LicenseRegistry` and then left with no door: no
/// `showLicensePage` anywhere in the app, so the notice the OFL asks to travel
/// with the fonts, and the attribution the Font Awesome brand marks are under,
/// shipped inside the binary where nobody could read them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the tile opens the licences, and says who owns what',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(Palette.pine),
        home: const Scaffold(body: LicensesTile()),
      ),
    );

    expect(find.text('Licenses'), findsOneWidget);

    await tester.tap(find.text('Licenses'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LicensePage), findsOneWidget);

    // Three different answers to "who owns this", and the page is the only
    // place in the app that gives all three.
    expect(find.textContaining('World English Bible'), findsWidgets);
    expect(find.textContaining('MIT'), findsWidgets);
    expect(find.textContaining('SIL Open Font License'), findsWidgets);

    // Named and versioned, so a reader reporting something can say which build.
    expect(find.text(appName), findsWidgets);
    expect(find.textContaining(appVersion), findsWidgets);
  });

  test('the typefaces put their OFL into the registry', () async {
    bundleTheTypefaces();

    final filedUnder = <String>[];
    await for (final entry in LicenseRegistry.licenses) {
      filedUnder.addAll(entry.packages);
    }

    // Filed under the family rather than lost in the pile under "flutter", so
    // a reader looking for Merriweather's terms finds them under Merriweather.
    expect(
      filedUnder,
      containsAll(['Merriweather', 'Inter', 'PlayfairDisplay']),
    );
  });
}
