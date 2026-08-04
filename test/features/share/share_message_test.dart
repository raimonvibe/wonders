import 'package:bible_wonders/features/share/share_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// A share has two halves and they are read differently.
///
/// The picture is looked at, so it carries a name — "Play Store App
/// “Wonders”". The message is a line of text in somebody's chat app,
/// where the useful thing is something to tap. They were the same string until
/// naming the app on the image left the message with nothing to follow.
void main() {
  const service = ShareService(
    siteLabel: 'Play Store App “Wonders”',
    link: 'https://example.test/wonders',
  );

  test('the message carries the reference, the wonder and somewhere to go', () {
    final wonder = testWonder();
    final message = service.messageFor(wonder);

    expect(message, contains(wonder.quoteRef!));
    expect(message, contains(wonder.title));
    expect(message, contains('https://example.test/wonders'));
  });

  test('it points at a link, not at the label on the picture', () {
    // The label is for looking at. A chat app makes nothing of it, and a
    // message ending in a name rather than an address is a message that told
    // somebody about an app and then did not say where it was.
    final message = service.messageFor(testWonder());
    expect(message, isNot(contains('Play Store App')));
  });

  test('the link is the last line, where a chat app will linkify it', () {
    final message = service.messageFor(testWonder());
    expect(message.split('\n').last, 'https://example.test/wonders');
  });

  test('our prose never travels with it', () {
    // Same rule the image obeys: whatHappened and hopeMeaning are ours, not
    // scripture, and a message carrying a verse reference must not mix them.
    final message = service.messageFor(testWonder());
    expect(message, isNot(contains('SECRET')));
  });
}
