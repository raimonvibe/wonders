import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/mark.dart';

/// A way for kept verses to leave the phone.
///
/// `library.db` is the only thing in this app the reader makes rather than
/// receives — everything else is rebuilt from the asset bundle. It survives a
/// text correction, which is why it is a separate database, but it does not
/// survive uninstalling the app or changing phone. Somewhere to put it is the
/// difference between marks being kept and merely being stored.
///
/// The output is plain readable text, not a backup blob. Reading it back in
/// would need a file picker this app does not otherwise want, and a list you
/// can paste into a journal or mail to yourself is worth more than one only
/// this app can open.
class LibraryExport {
  const LibraryExport._();

  static String compose(List<Mark> marks) {
    if (marks.isEmpty) return 'No verses kept yet.';

    final out = StringBuffer()
      ..writeln('Kept verses')
      ..writeln('Wonders and Hope — World English Bible, public domain.')
      ..writeln('${marks.length} ${marks.length == 1 ? 'verse' : 'verses'}.')
      ..writeln();

    for (final mark in marks) {
      out
        ..writeln(mark.reference)
        ..writeln(mark.preview);
      if (mark.hasNote) out.writeln('  Note: ${mark.note}');
      out.writeln();
    }

    return out.toString().trimRight();
  }

  /// Writes the list to a file and hands it to the share sheet.
  ///
  /// A file rather than a body of text: a reader with three hundred marks would
  /// otherwise hand a share target a string long enough for some of them to
  /// silently truncate it.
  static Future<void> share(List<Mark> marks) async {
    final file = File(
      p.join((await getTemporaryDirectory()).path, 'kept-verses.txt'),
    );
    await file.writeAsString(compose(marks), flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/plain')],
        subject: 'Kept verses',
      ),
    );
  }
}
