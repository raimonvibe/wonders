import 'package:bible_wonders/data/prefs.dart';
import 'package:bible_wonders/models/wonder.dart';
import 'package:bible_wonders/providers.dart';
import 'package:bible_wonders/theme/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Palette.lockedOf', () {
    test('reads the ids settings writes', () {
      expect(Palette.lockedOf('pine'), Palette.pine);
      expect(Palette.lockedOf('ocean'), Palette.ocean);
      expect(Palette.lockedOf('cedar'), Palette.cedar);
      expect(Palette.lockedOf(null), isNull);
    });

    test('keeps a pin from before palettes had names of their own', () {
      expect(Palette.lockedOf('old'), Palette.pine);
      expect(Palette.lockedOf('new'), Palette.ocean);
    });
  });

  group('cedar', () {
    test('the page ground is the brown linear gradient', () {
      expect(Palette.cedar.shade700, const Color(0xFF6B4223));
      expect(Palette.cedar.shade900, const Color(0xFF4A2E18));
      final colors = Palette.cedar.pageGradient.colors;
      expect(colors.first, Palette.cedar.shade700);
      expect(colors.last, Palette.cedar.shade900);
    });
  });

  group('ThemeController', () {
    Future<ThemeController> controller({String? lock}) async {
      SharedPreferences.setMockInitialValues({
        if (lock != null) 'theme-lock': lock,
      });
      return ThemeController(await Prefs.load());
    }

    test('starts in pine, and Follow keeps wearing the testament', () async {
      final theme = await controller();
      expect(theme.state, Palette.pine);
      expect(theme.isLocked, isFalse);

      theme.followTestament(Testament.aNew);
      expect(theme.state, Palette.ocean);
    });

    test('a pin holds against a testament change', () async {
      final theme = await controller();
      await theme.lockTo(Palette.cedar);
      expect(theme.state, Palette.cedar);
      expect(theme.isLocked, isTrue);

      theme.followTestament(Testament.aNew);
      expect(theme.state, Palette.cedar);
    });

    test('unlocking cedar returns to pine, not a brown Follow cannot wear',
        () async {
      final theme = await controller(lock: 'cedar');
      expect(theme.state, Palette.cedar);

      await theme.lockTo(null);
      expect(theme.state, Palette.pine);
      expect(theme.isLocked, isFalse);
    });

    test('unlocking ocean stays ocean until the next testament', () async {
      final theme = await controller(lock: 'ocean');
      await theme.lockTo(null);
      expect(theme.state, Palette.ocean);
    });
  });
}
