import 'package:flutter/material.dart';

import '../../app.dart' show appName, appVersion;

/// The way to everything the app is built out of.
///
/// Flutter collects a licence for every package in the tree, and `main` adds
/// the three typefaces' OFL to the pile — but none of it had a door. No
/// `showLicensePage` existed anywhere in the app, so the notice the OFL asks to
/// travel with the fonts, and the attribution the Font Awesome brand marks on
/// this very screen are under, shipped inside the binary where nobody could
/// read them. A licence nobody can open has not been honoured.
///
/// Its own widget rather than a few lines in the settings list because the
/// settings list cannot be built in a test — it reads `marksProvider`, whose
/// database has a private constructor — and this is the piece worth proving
/// actually opens.
class LicensesTile extends StatelessWidget {
  const LicensesTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: const Text('Licenses'),
      subtitle: const Text(
        'The scripture, the typefaces, and every package the app is built on.',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showLicensePage(
        context: context,
        applicationName: appName,
        applicationVersion: appVersion,
        // Three different answers to "who owns this", which is the whole reason
        // the page is worth reaching: the code is the author's to give away,
        // the scripture is nobody's, and the typefaces are somebody else's on
        // terms that are met by shipping them unchanged.
        applicationLegalese:
            '© 2026 Raimon Baudoin (raimonvibe). The application code is MIT '
            'licensed.\n\n'
            'Scripture is the World English Bible, in the public domain. The '
            'typefaces are under the SIL Open Font License 1.1 and ship '
            'unmodified.',
      ),
    );
  }
}
