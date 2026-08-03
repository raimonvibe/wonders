import 'package:bible_wonders/features/settings/privacy_tile.dart';
import 'package:bible_wonders/theme/app_theme.dart';
import 'package:bible_wonders/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Play wants the privacy policy in two places and the in-app one is the half
/// people miss. It is also the half that can rot quietly: the URL is a string,
/// and a string that stops resolving fails in the store rather than in a build.
void main() {
  testWidgets('More offers the policy, and says what it will do', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(Palette.pine),
        home: const Scaffold(body: PrivacyTile()),
      ),
    );

    expect(find.text('Privacy policy'), findsOneWidget);
    // The open-in-new mark, so a reader knows the tap leaves the app before
    // they make it.
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });

  group('the hosted policy URL', () {
    final uri = Uri.parse(PrivacyTile.url);

    // Play's requirements for the page, as far as a test can check them: an
    // active, publicly accessible, non-geofenced URL, and no PDF.
    test('is https, not http', () => expect(uri.scheme, 'https'));

    test('is not a PDF', () {
      expect(uri.path.toLowerCase().endsWith('.pdf'), isFalse);
    });

    test('names a real host', () {
      expect(uri.host, isNotEmpty);
      expect(uri.host, contains('.'));
      expect(uri.host, isNot(contains('example')));
      expect(uri.host, isNot('localhost'));
    });
  });
}
