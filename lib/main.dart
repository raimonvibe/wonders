import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/bible_repository.dart';
import 'data/library_repository.dart';
import 'data/prefs.dart';
import 'data/wonders_repository.dart';
import 'features/speech/speech_audio_handler.dart';
import 'features/speech/speech_controller.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Everything the app reads is bundled, so it is all resolvable before the
  // first frame. Doing it here rather than in a FutureBuilder means no screen
  // has to render a spinner for data that was never going to be slow — the one
  // cost is the first launch, where bible.db is copied out of the asset
  // bundle. See BibleDatabase.open.
  final prefs = await Prefs.load();
  final wonders = await WondersRepository.load();
  final bible = await BibleRepository.open();
  final library = await LibraryRepository.open();
  final marks = await library.all();

  final speech = SpeechController(prefs);
  await _connectToTheLockScreen(speech);

  // After the audio session exists, not before: audio_service installs one on
  // iOS and SpeechController's own category adjusts it. The other order leaves
  // whichever ran last in charge.
  await speech.initialise();

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        wondersProvider.overrideWithValue(wonders),
        bibleProvider.overrideWithValue(bible),
        libraryProvider.overrideWithValue(library),
        marksProvider.overrideWith((ref) => LibraryController(library, marks)),
        speechProvider.overrideWith((ref) => speech),
      ],
      child: const BibleWondersApp(),
    ),
  );
}

/// Put read-aloud on the lock screen, and let it keep speaking off screen.
///
/// A failure here is not fatal. Without the service, speech still works
/// everywhere in the app; it just stops when the system suspends us, which is
/// exactly where the feature stood before this was wired up.
Future<void> _connectToTheLockScreen(SpeechController speech) async {
  try {
    await AudioService.init(
      builder: () => SpeechAudioHandler(speech),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.raimonvibe.bible_wonders.speech',
        androidNotificationChannelName: 'Read aloud',
        androidNotificationChannelDescription:
            'Controls for the passage being read aloud.',
        androidNotificationIcon: 'mipmap/ic_launcher',

        // Keep the service in the foreground through a pause.
        //
        // Since Android 12 an app cannot restart a foreground service from the
        // background, so the alternative — tearing it down on pause — makes
        // pressing play on the lock screen throw rather than resume. The cost
        // is that the notification stays while paused, which is what every
        // audiobook app does anyway.
        androidStopForegroundOnPause: false,
      ),
    );
  } catch (_) {
    // No media session on this platform, or the service could not start.
  }
}
