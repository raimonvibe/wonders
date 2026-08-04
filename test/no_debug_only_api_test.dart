import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Debug-only Flutter API must not be called from production code.
///
/// A whole class of bug hides here, and no ordinary test can find it. Getters
/// like `RenderObject.debugNeedsPaint` assign their result inside an assert:
///
/// ```dart
/// bool get debugNeedsPaint {
///   late bool result;
///   assert(() { result = _needsPaint; return true; }());
///   return result;
/// }
/// ```
///
/// A release build strips asserts, the local is never assigned, and the getter
/// throws `LateInitializationError: Local 'result' has not been initialized`.
/// The Flutter documentation says it outright: "In release builds, this
/// throws."
///
/// The trap is that **the test suite runs with asserts enabled**, so such a
/// call passes every test, every `flutter run`, and every emulator session,
/// then fails on every device a reader would install the app on. Sharing a
/// wonder shipped in exactly that state until 4 August 2026 — caught by hand,
/// on a phone, because nothing else was ever going to catch it.
///
/// So this test does not run the code. It reads it.
void main() {
  test('no debug-only API is called outside an assert', () {
    // `.debugSomething` — the naming convention Flutter uses for every member
    // that is only meaningful, or only safe, in a debug build.
    final debugMember = RegExp(r'\.debug[A-Z]\w*');
    final offenders = <String>[];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();

        // Comments discuss this API; they do not call it.
        if (trimmed.startsWith('//')) continue;
        if (!debugMember.hasMatch(line)) continue;

        // An assert block spans a few lines, so the opening `assert(` is
        // usually just above the call rather than on the same line. Three
        // lines of lookback covers the shape Flutter's own docs recommend and
        // is deliberately crude: a false positive here costs a comment, and a
        // false negative costs a feature that only breaks after release.
        final window = lines.sublist(max(0, i - 3), i + 1).join('\n');
        if (window.contains('assert(')) continue;

        offenders.add('${file.path}:${i + 1}  ${line.trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Debug-only API called outside an assert. This compiles, passes '
          'every test and works in debug — then throws on release builds:\n'
          '${offenders.join('\n')}',
    );
  });
}
