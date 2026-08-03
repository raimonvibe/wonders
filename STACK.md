# The stack

Everything this app is built out of, and what each piece is load-bearing for.
Written 3 August 2026 against commit `7db6cc4`.

Versions are the *resolved* ones from `pubspec.lock`, not the constraints in
`pubspec.yaml` — the constraint is what we allow, the lock is what actually
ships.

---

## Toolchain

| Piece | Version | Notes |
| --- | --- | --- |
| Flutter | 3.41.7 (stable) | Engine `7a53c052bc`, released 15 Apr 2026 |
| Dart | 3.11.5 | `pubspec.yaml` floor is `^3.6.0` |
| Gradle | 8.14 | `android/gradle/wrapper` |
| Android Gradle Plugin | 8.11.1 | `android/settings.gradle.kts` |
| Kotlin (android plugin) | 2.2.20 | |
| JDK | Temurin 17.0.17 | Pinned in `gradle.properties`; see below |
| Android SDK | 36.1.0 | |
| compileSdk / targetSdk | 36 (Android 16) | via `flutter.compileSdkVersion` |
| minSdk | 24 (Android 7.0) | |
| iOS deployment target | 13.0 | `Runner.xcodeproj` |

### The JDK pin

`android/gradle.properties` hard-codes `org.gradle.java.home` to a Temurin 17
path. This is deliberate and load-bearing: Android Studio's bundled JBR is Java
25, which AGP 8.11 rejects with an exception whose entire message is the string
`25.0.2`. It is also **machine-specific** — the line has to change when the
machine does. A `flutter create` project without this pin fails on this machine
with exactly that `25.0.2` error.

---

## Dependencies

### Runtime

| Package | Version | What it is load-bearing for |
| --- | --- | --- |
| `flutter_riverpod` | 2.6.1 | All app state. Held at 2.x deliberately — Riverpod 3 needs a Dart floor above `^3.6.0` and deprecates `StateNotifier`, which every provider here uses. |
| `go_router` | 17.3.0 | `StatefulShellRoute.indexedStack` gives each bottom-nav tab its own navigator stack, which is what stops a wonder's passage stealing the Bible tab's place. |
| `sqflite` | 2.4.2+1 | Two databases: `bible.db` (read-only, shipped) and `library.db` (the reader's marks). |
| `path` | 1.9.1 | Joining database paths. |
| `path_provider` | 2.1.6 | Temp dir for share files. |
| `shared_preferences` | 2.5.5 | Resume state. Keys mirror the website's localStorage names. |
| `flutter_tts` | 4.2.5 | Read-aloud. |
| `audio_service` | 0.18.19 | Lock-screen controls and background speech. |
| `share_plus` | 13.3.0 | Share a wonder as a PNG; export kept verses as text. |
| `google_fonts` | 8.2.1 | Merriweather (scripture), Inter (chrome), Playfair (titles). **Fetched at runtime** — see Known risks. |
| `url_launcher` | 6.3.2 | The maker's links on the More tab. |
| `font_awesome_flutter` | 11.0.0 | Brand marks only; Material ships no LinkedIn or TikTok glyph. |
| `scrollable_positioned_list` | 0.3.8 | Jumping the reader to a verse. |

### Build-time only

| Package | Version | Purpose |
| --- | --- | --- |
| `flutter_lints` | 6.0.0 | Lint set. `flutter analyze` is clean. |
| `flutter_launcher_icons` | 0.14.4 | Native icons from `branding/app-icon.png`. |
| `flutter_native_splash` | 2.4.7 | Splash from the same source image. |
| `image` | 4.8.0 | Used by `tool/make_branding.dart` to derive the adaptive-icon foreground and splash mark. |

---

## Native setup that is load-bearing

All of this is in `android/app/src/main/AndroidManifest.xml` and
`MainActivity.kt`, and none of it is boilerplate.

- **`MainActivity extends AudioServiceActivity`**, not `FlutterActivity`. Without
  it audio_service starts a second `FlutterEngine` and the notification drives a
  `SpeechController` the app cannot see.
- **`<service android:foregroundServiceType="mediaPlayback">`** plus
  `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permissions.
  Android 14 refuses to start a foreground service without a declared type.
- **`POST_NOTIFICATIONS`**, requested at the first reading rather than at launch,
  over a `wonders/notifications` method channel answered by `MainActivity`.
- **`<queries><intent><action android:name="…TTS_SERVICE"/>`**. Since Android 11
  a package is invisible unless declared. flutter_tts does not declare it; without
  this the engine cannot be seen and every Listen button is silent.
- **`<queries>` for `https` and `mailto`**, or `url_launcher` reports every
  maker link as unlaunchable.
- **`INTERNET`**, needed by `google_fonts` at runtime.
- **iOS `UIBackgroundModes: audio`**, for speech that continues off screen.

---

## Data

- `assets/bible.db` — 7.5 MB SQLite, the World English Bible, all 66 books,
  committed deliberately (a repo that does not build is worse than a large one).
  Copied out of the bundle to the databases directory on first launch because
  sqflite cannot open an asset in place; re-copied when `_assetVersion` in
  `BibleDatabase` is bumped.
- `assets/wonders.json` — 290 KB, 178 wonder cards.
- `library.db` — created on first run, never shipped. Kept separate from
  `bible.db` precisely because `bible.db` is replaced wholesale on a text
  correction.

---

## Known risks in this stack

Recorded here so they are not rediscovered from scratch. Findings and their
status live in `AUDIT.md`.

1. **`google_fonts` fetches typefaces over the network at first use.** The About
   text promises the app works with no connection; the fonts do not.
2. **`share_plus` needs `sharePositionOrigin`.** Historically iPad-only; iOS 26
   validates it on iPhone too.
3. **Android 16 enforces edge-to-edge.** `targetSdk` is 36, so there is no
   opt-out.
4. **`-network` TTS voices are not always in `getVoices`.** They depend on the
   engine reaching its server, which makes any default derived from them unstable.
5. **The Android speech service binds asynchronously.** `main()` runs before it
   is ready, so anything asked of the engine at launch may quietly return null.
6. **The emulator is not a reliable renderer.** A Flutter app can come up pure
   black under the default `hw.gpu.mode=auto`; `angle_indirect` fixes it.

---

## Not covered by any automated check here

Windows-only development machine. There is no macOS, so **nothing on the iOS
side of this stack has ever been compiled or run** — the iOS deployment target,
the `UIBackgroundModes` entry, the audio session category in
`SpeechController._init`, and the `share_plus` popover behaviour are all
unverified by anything but reading. Same for the Play release build: `key.properties`
lives outside the tree and is not present here, so only debug builds have run.
