import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bundleTheTypefaces();

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

  // Started after the audio session exists, not before: audio_service installs
  // one on iOS and SpeechController's own category adjusts it. The other order
  // leaves whichever ran last in charge.
  //
  // Started, not awaited. Binding the speech engine takes as long as the device
  // takes — on Android the service is bound asynchronously and the voice list
  // can need a second of asking — and none of the first frame depends on it.
  // Awaiting it here put that wait in front of the splash screen, and made a
  // device whose engine never answers a device that never leaves it.
  // SpeechController.start awaits the same future before it speaks, so the
  // first reading still gets the reader's own voice; it is only the first
  // frame that no longer waits for it.
  unawaited(speech.initialise());

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

/// Read the typefaces out of the app rather than off the network.
///
/// The About screen says the app works "with no connection at all", and until
/// now that was true of the words and false of the shapes they were set in:
/// `google_fonts` fetches from fonts.gstatic.com at first use, so a reader who
/// installed on a plane got the system fallback face, and the first share image
/// of that session was typeset differently from every later one. It is the kind
/// of failure that never produces a bug report — nothing is broken, the app is
/// just quietly not the app.
///
/// The eight files in assets/fonts are the exact variants this app asks for
/// through the `GoogleFonts` API, taken from the package's own manifest and
/// checked against the SHA-256 and byte length it records for each. Nothing is
/// subset or re-hinted, so what renders offline is what rendered online.
///
/// `allowRuntimeFetching = false` is the half that matters: without it a
/// variant nobody bundled would still be fetched, and the offline claim would
/// be true right up until the day somebody adds a bold.
///
/// Public only so `licenses_test` can call it and check the OFL actually
/// reaches the registry; nothing but `main` should be calling it.
void bundleTheTypefaces() {
  GoogleFonts.config.allowRuntimeFetching = false;

  // The OFL asks that the licence travel with the font. Registering it here
  // puts all three in the app's own "Licenses" page, alongside every other
  // dependency, rather than in a file only the repository can see.
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Merriweather', 'Inter', 'PlayfairDisplay']) {
      final licence = await rootBundle.loadString(
        'assets/fonts/OFL-$family.txt',
      );
      yield LicenseEntryWithLineBreaks([family], licence);
    }
  });
}

/// Put read-aloud on the lock screen, and let it keep speaking off screen.
///
/// A failure here is not fatal. Without the service, speech still works
/// everywhere in the app; it just stops when the system suspends us, which is
/// exactly where the feature stood before this was wired up.
/// Long enough for a device that is going to answer, short enough that one that
/// is not still gets an app.
///
/// AudioService.init is the last thing between the process starting and the
/// first frame, and it talks to a platform service that binds asynchronously.
/// Without a bound on it, a service that never binds is indistinguishable from
/// a hung app: no error, no frame, a black screen for as long as the reader is
/// willing to wait. The catch below already treats a failure as survivable, so
/// treating silence the same way is the only consistent thing to do.
const _lockScreenTimeout = Duration(seconds: 8);

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
    ).timeout(_lockScreenTimeout);
  } catch (_) {
    // No media session on this platform, the service could not start, or it
    // never answered. None of the three is a reason to have no app.
  }
}
