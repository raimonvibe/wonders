import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The privacy policy, from inside the app.
///
/// Play's User Data policy asks for it twice, and the second one is easy to
/// miss: *"All apps must post a privacy policy link in the designated field
/// within Play Console, and a privacy policy link or text within the app
/// itself."* It is not conditional on what the app collects — the same policy
/// says apps that touch no personal data must still have one. This app touches
/// none, and still needs this tile.
///
/// A link rather than the text, because a policy that can be corrected without
/// shipping a release is a policy that stays true. The page is plain HTML on a
/// public URL, which is what Play asks for: no PDF, no geofence, not editable
/// by the reader.
class PrivacyTile extends StatelessWidget {
  const PrivacyTile({super.key});

  /// Hosted apart from the app so a wording fix is a deploy, not a release.
  /// The source of this page lives at index.html in the repository root.
  static const url = 'https://privacy-policy-wonders-and-hope.vercel.app/';

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        // Saying so beats a tap that appears to do nothing — and this is the
        // one link in the app a reader may have a reason to insist on.
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the privacy policy.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nothing on this device opens web pages.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.lock_outline),
      title: const Text('Privacy policy'),
      subtitle: const Text(
        'The app collects nothing and sends nothing. The policy says so in '
        'full.',
      ),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => _open(context),
    );
  }
}
