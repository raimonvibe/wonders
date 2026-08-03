# Stack audit — 3 August 2026

Every dependency in [STACK.md](STACK.md) taken one at a time: what is known to
go wrong with it, whether *this* codebase goes wrong that way, and what was done.

Baseline for this pass is commit `7db6cc4`. `flutter analyze` was already clean
and stayed clean; the suite went from 83 tests to 88.

Verdicts:

- **Fixed** — a real defect, changed, and verified.
- **Fixed, unverified** — a real defect, changed, but not provable on this
  machine. Every one of these is in [Needs testing on your end](#needs-testing-on-your-end).
- **Checked, sound** — a known pitfall that this codebase does not have.
- **Open** — real, not fixed, because it needs a decision that is yours.

---

## Fixed

### 1. The reader's voice arrived after the first reading had started
`flutter_tts` · `lib/features/speech/speech_controller.dart`

Android binds the speech service asynchronously, and `main()` runs before it is
ready, so `getVoices` routinely answered null on the first ask. With no list
there was no voice to apply: the reading started on the engine's system default,
and the reader's saved voice only arrived when something later asked again. This
is the "the voice changed on its own" report — the app switching from Australian
to Indian English between one reading and the next, with nothing on screen to
explain it.

`_loadVoices` now asks up to six times, 250 ms apart, so the list is there within
about a second and a half of launch, long before anyone presses Listen.

**Verified on device.** Cold start, no user interaction:

```
08:07:53.762  currentLocale = en-US        ← engine default
08:07:55.220  Displayed …MainActivity: +2s956ms
08:07:55.220  currentLocale = en-IN        ← the saved voice, applied unprompted
```

Before this change, `en-IN` did not appear until the first Listen press.

### 2. Nothing before the first frame can hang the app any more
`audio_service` · `lib/main.dart`

`main()` awaited `AudioService.init` and `speech.initialise()` before `runApp`.
Both talk to platform services that bind asynchronously, and neither had a
bound. A service that never answers was therefore indistinguishable from a hung
app — no error, no frame, a black screen for as long as the reader would wait.
Having just spent an afternoon on a black screen with a different cause, this
seemed worth closing.

`AudioService.init` now has an 8-second timeout, falling into the `catch` that
already treats failure as survivable. `speech.initialise()` is started rather
than awaited — `SpeechController.start` awaits the same future before it speaks,
so the first reading still gets the right voice; only the first frame stops
waiting.

**Verified on device.** First frame 2.956 s, down from 3.5–3.8 s.

### 3. The default voice wandered between launches
`flutter_tts` · `lib/features/speech/speech_voices.dart`

`_qualityScore` awarded +5 for `network` in a voice name, ranking server-side
voices first. Those are exactly the voices that drop out of `getVoices` when the
engine cannot reach its server, so the best-ranked English voice was a different
one from launch to launch. A reader who had never chosen a voice heard the
passage in a new accent for no reason they could see.

Network voices now rank just below their `-local` twin. They are still in the
picker.

**Verified by unit test** (`prefers a local voice to its network twin`). Not
observable on the emulator, whose saved voice is an explicit choice.

### 4. A stand-in voice could have become the preference
`lib/features/speech/speech_controller.dart`

`_init` resolved against `state.voiceId`, which may already hold a substitute.
Now it resolves against `_prefs.speechVoiceId` — what the reader actually chose —
so a substitution lasts exactly as long as the absence that caused it.

Being straight about this one: it is **hardening, not a live bug fix**. The
current memoisation already makes the cementing path unreachable. The change
makes it impossible by construction rather than by luck.

**Verified by unit tests** (`a voice that is only temporarily missing`, 2 cases).

### 5. `pubspec.lock` was not committed
`.gitignore`

The Dart guidance splits on package type: a library ignores its lockfile, an
application commits it. This is an application, and one shipped to a store.
Ignoring it meant a fresh clone resolved whatever was newest that day — so the
build that goes to Play would not be the build anyone had run, and a plugin that
breaks on a point release would break in the release rather than on the machine
that could have caught it.

The ignore rule is gone, with a comment saying why, matching the existing note
about `assets/` being committed deliberately.

---

## Fixed, unverified

### 6. The share sheet had no origin — broken on iPad, and now on iPhone
`share_plus` · `lib/features/share/share_service.dart`,
`lib/features/library/library_export.dart`, `lib/features/library/library_screen.dart`

Neither share call passed `sharePositionOrigin`. iOS presents the sheet as a
popover on iPad and needs a rectangle to hang the arrow off; without one it has
historically thrown. Since iOS 26 the origin is validated on iPhone too, where
an omitted or zero rect makes the sheet **fail to present at all** — the share
button simply does nothing.

Both call sites now pass one, via a shared `shareOrigin(BuildContext)` helper
measured before the first `await`, while the tapped control is certainly still
mounted. Android ignores the parameter.

**Cannot be verified here** — no macOS, no iOS device. See below.

---

## Checked, sound

| Area | Known pitfall | This codebase |
| --- | --- | --- |
| `audio_service` | Android 14 refuses a foreground service with no declared type | `foregroundServiceType="mediaPlayback"` plus both `FOREGROUND_SERVICE*` permissions are present |
| `audio_service` | Second `FlutterEngine` if the activity is a plain `FlutterActivity` | `MainActivity extends AudioServiceActivity` |
| `audio_service` | Android 12+ cannot restart a foreground service from the background, so tearing it down on pause breaks lock-screen play | `androidStopForegroundOnPause: false`, with the reasoning in a comment |
| Android 16 (`targetSdk` 36) | Edge-to-edge is enforced with no opt-out; content can slide under the system bars | Renders correctly — screenshotted on Wonders, Bible and More. Material `Scaffold`/`NavigationBar` handle the insets and the sheets use `SafeArea` |
| `flutter_tts` | Android 11 package visibility hides the TTS engine | `<queries>` declares `TTS_SERVICE`; flutter_tts does not do this for you |
| `flutter_tts` | `setVoice` NPEs when the engine is unbound | Real, but it is the plugin's bug and surfaces as a `PlatformException` that `_safely` already swallows |
| `url_launcher` | Android 11 package visibility makes `canLaunchUrl` false for everything | `<queries>` declares `https` and `mailto` |
| `sqflite` | Cannot open a database from the asset bundle in place | Copied out once, guarded by `_assetVersion`, version file written **after** the copy so a kill mid-copy re-copies rather than corrupting |
| `sqflite` | Scripture and user data in one file means a content update destroys marks | Two databases, deliberately, with the reasoning in `LibraryDatabase` |
| `scrollable_positioned_list` | Undisposed controller | `ItemScrollController` is not a `ChangeNotifier`; nothing to dispose |
| `share_plus` | A long string silently truncated by the share target | Marks are exported as a file, not a body of text |
| Lints | Stale API use, `BuildContext` across an await | `flutter_lints` 6.0.0, `flutter analyze` clean |
| Toolchain | AGP 8.11 rejects Java 25 with the bare message `25.0.2` | Pinned to Temurin 17 in `gradle.properties`. Confirmed the hard way: a `flutter create` project without the pin fails with exactly that on this machine |

---

## Open — needs a decision from you

*(A is kept here, struck through, rather than deleted: the reasoning is why the
fonts are committed and worth finding again.)*

### ~~A. `google_fonts` fetches typefaces over the network~~ — closed
**Decided and done**, in the UI pass after this audit. `assets/fonts/` now
carries the eight variants the app asks for through the `GoogleFonts` API —
Merriweather Regular and Italic, Inter Regular, Medium and SemiBold, Playfair
Display Regular, SemiBold and Italic — taken from the package's own manifest and
verified against the SHA-256 and byte length it records for each.
`main()` sets `GoogleFonts.config.allowRuntimeFetching = false`, so an unbundled
weight is now a visible fallback rather than a silent download, and the three
OFL texts are registered into the app's Licenses page.

Cost: **2.4 MB**, of which Merriweather is 1.1 MB — its current release carries
a very wide language coverage.

It was not only cosmetic. With the real faces bundled, the share card turned out
to be **clipping the scripture mid-sentence**: `ShareCard._quoteSizeFor` stepped
the type size down by character count, tuned against whatever face the fallback
happened to be, and the quote shared a flex line with a `Spacer` that took half
the slack regardless. Exodus 14:21 lost its last line and a half under the
reference rule — in a PNG that goes out to other people. The size is now chosen
by laying the text out with a `TextPainter` and asking whether it fits. Both
share goldens were regenerated and are the first ones that show the real
typography.

### B. The Tour tab is still a scaffold
`lib/features/tour/tour_screen.dart` says so itself. `_steps` is
`wondersProvider.startHere(limit: 14)` — the top 14 of the familiarity-ranked
shortlist — where the intent is the curated fourteen from the website's
`miraclesTour.ts`, exported alongside the catalog by `scripts/export-wonders.js`.

Not a defect; unfinished work, flagged so it does not get lost.

### C. The emulator has 2 GB of RAM
`Pixel_10_Pro` is configured with `hw.ramSize=2048`, which is where the 40–120
skipped frames on cold start come from. 4 GB would make on-device testing
represent a real phone better. Cosmetic for correctness, misleading for
performance work.

---

## Needs testing on your end

Nothing in this section was checked by anything but reading. The single reason
for most of it: **this is a Windows machine with no macOS and no physical
device.**

### iOS — none of it has ever been compiled
There is no `ios/Podfile` yet (Flutter generates it on the first macOS build),
so the iOS half of this stack is unbuilt, not just untested.

1. **Share on iPhone and iPad.** The fix above is the whole point. On iPad,
   confirm the popover appears anchored to the button rather than throwing; on
   iPhone (iOS 26+), confirm the sheet presents at all. Both the wonder-card
   share and More → Kept verses → Export.
2. **The audio session.** `SpeechController._init` sets
   `IosTextToSpeechAudioCategory.playback` with `duckOthers` and
   `interruptSpokenAudioAndMixWithOthers`. Check that the ring/silent switch does
   *not* silence read-aloud, and that another spoken-word app yields rather than
   talks over it.
3. **Ordering against audio_service.** `AudioService.init` installs its own audio
   session and the category above adjusts it. My timeout change alters what
   happens when init is slow — worth one run where you watch for speech going
   silent after a slow start.
4. **Deployment target.** 13.0. Confirm every plugin still accepts it;
   `share_plus` 13 and `flutter_tts` 4 have both moved their floors before.
5. **Background audio.** `UIBackgroundModes: audio` is declared. Lock the phone
   mid-chapter and confirm the reading continues.

### Android hardware — the emulator is not a phone
6. **Network TTS voices.** Every synthesis on this emulator was
   `-seanet-embedded`; it never once reached the server. So the *entire*
   network-voice code path — the thing behind two of the fixes above — is
   untested against a real server. On a real phone, pick a `-network` voice and
   confirm it sounds as expected and does not flip mid-chapter.
7. **Lock-screen and notification controls.** Play, pause, next, previous, and
   swipe-to-dismiss meaning stop. The media session is created on the emulator
   but I never drove the notification.
8. **Headset and Bluetooth buttons.** `MediaButtonReceiver` is declared; pinch to
   pause, double-tap to skip a verse.
9. **The `POST_NOTIFICATIONS` prompt.** Requested at the first reading, not at
   launch. I never saw the dialog — the emulator may have auto-granted. Test
   both granting and refusing; refusing must lose only the lock-screen controls,
   never the speech.
10. **Foreground service under real conditions.** Android 14/15 restrictions bite
    hardest on Samsung and Xiaomi builds. Start a reading, background the app,
    leave it several minutes.
11. **First-launch database copy.** `bible.db` is 7.5 MB, copied before the first
    frame. On this emulator it is invisible; on a slow phone with slow storage it
    is a real wait. Time a first launch after a clean install.

### Build and release
12. **Release build.** Only debug builds have run here — `key.properties` lives
    outside the tree and is not on this machine. A release build turns on R8, and
    shrinking is where reflective plugin code goes wrong. Run
    `flutter build appbundle` and smoke-test the artefact, watching read-aloud and
    share in particular.
13. **The committed lockfile.** Now that `pubspec.lock` is tracked, do one clean
    clone and `flutter pub get` to confirm it resolves and builds.

### Things I changed but could not trigger
14. **The `AudioService.init` timeout.** 8 seconds, and I have no way to make the
    service hang on demand. The code path is a `catch` that was already there;
    the risk is that 8 s is the wrong number on a cold, slow device — too short
    and you lose lock-screen controls that would have arrived. Worth one cold
    start on the slowest phone you have.
15. **The voice-list retry ceiling.** Six asks over 1.5 s was enough here every
    time. A slower device might need more; the symptom would be an empty Voice
    picker on the More tab right after launch that fills in once you press
    Listen.

### Not covered by any test, here or on your end
16. Sleep timer at each of its five settings, including the "finishes the line it
    is on" behaviour.
17. Marks: create, recolour, annotate, delete, remove-all, and export.
18. Search, across all three ranking tiers.
19. Deep links into `/wonders/:id?page=passage`.
