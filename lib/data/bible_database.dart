import 'dart:io';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the bundled World English Bible database.
///
/// sqflite cannot read a database out of the asset bundle in place, so the
/// file is copied to the app's database directory once, on first launch, and
/// opened read-only from there afterwards. [_assetVersion] is what forces a
/// re-copy after the asset is rebuilt: bump it whenever
/// `node scripts/build-bible-db.js` changes the schema or the text.
class BibleDatabase {
  BibleDatabase._(this.db);

  static const _assetPath = 'assets/bible.db';
  static const _fileName = 'bible.db';

  /// Bump on any schema or content change in scripts/build-bible-db.js.
  static const _assetVersion = 1;
  static const _versionFileName = 'bible.db.version';

  final Database db;

  static BibleDatabase? _instance;

  static Future<BibleDatabase> open() async {
    final existing = _instance;
    if (existing != null) return existing;

    final dir = await getDatabasesPath();
    final dbPath = p.join(dir, _fileName);
    final versionFile = File(p.join(dir, _versionFileName));

    final needsCopy = !await File(dbPath).exists() ||
        !await versionFile.exists() ||
        await versionFile.readAsString() != '$_assetVersion';

    if (needsCopy) {
      await Directory(dir).create(recursive: true);
      final ByteData bytes = await rootBundle.load(_assetPath);
      await File(dbPath).writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      await versionFile.writeAsString('$_assetVersion', flush: true);
    }

    // Read-only: nothing the app does writes to scripture. Bookmarks and notes
    // belong in their own database, not this one.
    final db = await openDatabase(dbPath, readOnly: true);
    return _instance = BibleDatabase._(db);
  }

  Future<void> close() async {
    await db.close();
    _instance = null;
  }
}
