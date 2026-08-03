import 'dart:io';

import 'package:bible_wonders/app.dart';
import 'package:flutter_test/flutter_test.dart';

/// pubspec.yaml is where the version really lives.
///
/// [appVersion] is a copy of it, made so the licences page can name the build
/// without a plugin that asks the platform at runtime. A copy of a number is a
/// copy that drifts, and the drift would be invisible — the page would keep
/// saying 1.0.0 through every release after it, which is worse than saying
/// nothing, because somebody would believe it.
void main() {
  test('the version on the licences page is the version being built', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final line = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec)
        ?.group(1);

    expect(line, isNotNull, reason: 'pubspec.yaml has no version:');

    // "1.0.0+1" — the build number after the plus is Play's, not the reader's.
    expect(
      line!.split('+').first,
      appVersion,
      reason: 'lib/app.dart says $appVersion; pubspec.yaml says $line',
    );
  });
}
