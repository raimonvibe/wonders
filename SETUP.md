# Wonders and Hope — the Flutter app

A mobile reading of the same catalog the website serves: the Bible on one
screen, the 178 wonders on another, and one swipe between a wonder's card and
the chapter it happened in.

`android/` and `ios/` **are** checked in. They used to be left out, on the
grounds that `flutter create` regenerates them — and that was true while they
held nothing but boilerplate. It stopped being true when read-aloud landed:
`AndroidManifest.xml` carries the `TTS_SERVICE` query and the audio_service
`<service>` and `<receiver>`, `MainActivity` extends `AudioServiceActivity`, and
`Info.plist` declares `UIBackgroundModes: audio`. A regenerated native project
has none of that, and the app it produces has silent Listen buttons and no lock
screen, with nothing in the logs to say why. Committing them is the cheaper
mistake.

## Where the content comes from

This Flutter app is standalone under
`~/Documenten/Mobile Development/wonders/bible-wonders-flutter`.

Nothing in here is the source of truth for the cards or Bible text. Both assets
are generated from the Next.js website repo
(`~/Documenten/web-development/002bible-wonders`), so a card is still only ever
written once, in that project's `lib/wonders/`, and still only ships if
`npm run validate:wonders` passes there.

```bash
# from the website repo, not this directory
cd ~/Documenten/web-development/002bible-wonders
npm run flutter:assets
```

That writes into this app's `assets/` (override with `FLUTTER_APP_ROOT` if you
move the folder). The two scripts:

| Script (in website repo) | Output | What it does |
| --- | --- | --- |
| `scripts/build-bible-db.js` | `assets/bible.db` (7.5 MB) | Splits the WEB chapter blobs on their `[n]` markers into 31,105 verse rows and builds an FTS5 index over them. |
| `scripts/export-wonders.js` | `assets/wonders.json` (284 KB) | Runs the validator, then exports the compiled TypeScript catalog. Refuses to export a theme or era the Dart enums don't know. |

Re-run `npm run flutter:assets` in the website repo after editing any card. If
the database schema changes, bump `_assetVersion` in
`lib/data/bible_database.dart` — that is what forces the copied-out copy on the
device to be replaced.

The two generated files are already present for a first run. They are
gitignored if you init a repo here; regenerate them from the website when
content changes.

## First run

The native projects come with the project, so there is no `flutter create` step.
Assets are already in `assets/`. Fetch packages and go:

```bash
flutter pub get
flutter run
```

**Do not run `flutter create` in this directory.** It would overwrite the native
configuration above with defaults, and the damage is quiet: the app still
builds, it just never speaks.

The branding commands are only needed after `branding/app-icon.png` changes,
because what they produce is committed too:

```bash
dart run tool/make_branding.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

See **Branding** below.

Requires Flutter 3.27 or newer (Dart 3.6+) — the source uses `Color.withValues`,
which landed in that release.

## The one architectural rule

The app has a Bible tab and a Wonders tab, but a wonder's passage **opens
inside the Wonders tab**, never by switching to the Bible tab.

`lib/router.dart` uses `StatefulShellRoute.indexedStack`, so each tab keeps its
own navigator stack. `WonderDetailScreen` is a two-page `PageView` — the card,
then the passage — which is the phone translation of the website's 50/50 dock.
Following a card into Exodus 14 therefore costs you neither your place in the
catalog nor whatever chapter the Bible tab was left on.

Both pages render the same `PassageView`; the only difference between reading a
chapter and being sent to one is whether a highlight range was passed. If you
ever find yourself writing a second reader, something has gone wrong.

A wonder's passage **opens on the cited verse**, not at verse 1. That is
`initialScrollIndex`, not a scroll after the fact, so there is no travel and no
flash of the wrong text. It is also why `PassageView` uses
`ScrollablePositionedList` rather than a `ListView`: a lazy list has not built
the verse you want to reach, so `GlobalKey.currentContext` is null and
`Scrollable.ensureVisible` returns silently — failing in exactly the case it
exists for, and appearing to work whenever the target happened to be on screen
already. Index-based scrolling does not need the target built. The same fix is
what lets the spoken verse be followed through a whole chapter.

The list is keyed by chapter id. `initialScrollIndex` is honoured only on a
list's first build, and without the key the reader would carry their offset from
Genesis 50 into Exodus 1.

## Layout of the source

```
lib/
  main.dart              resolves prefs, catalog and database before first frame
  app.dart               MaterialApp.router, animated palette switch
  router.dart            the four tabs and their stacks
  providers.dart         Riverpod: repositories, theme, path state
  models/                Wonder, PassageRef, Book/Chapter/Verse
  data/
    bible_database.dart  copies assets/bible.db out of the bundle once
    bible_repository.dart  every scripture query, including FTS search
    library_database.dart  the reader's marks — the one writable database
    library_repository.dart  reads and writes against it
    wonders_repository.dart  the catalog, and the reading-path lookups
    reading_paths.dart   the four paths and the sort modes
    prefs.dart           resume state, on the website's localStorage keys
  features/
    shell/               the bottom nav
    wonders/             home, card body, and the card ⇄ passage detail
    bible/               books, chapters, reader, and the shared PassageView
    tour/                the guided tour (scaffold — see below)
    speech/              read aloud: the controller, the queue, the transport
    library/             the reader's own marked verses
    share/               render a card to PNG and hand it to the share sheet
    settings/
  theme/                 the pine and ocean palettes, and the two ThemeDatas
```

## Sharing a card

`features/share/` renders a fixed 1080×1350 widget off-screen and captures it at
3× to a PNG. It is not a screenshot of the on-screen card.

The content rule is hard: **only the verbatim quote and its reference go on the
image.** Those are public-domain WEB text and validator-checked. The
`whatHappened` and `hopeMeaning` prose is ours, and putting it in the same frame
as a scripture reference invites someone to read it as the Bible saying it.

## Reading aloud

Every screen with something to say has a Listen button in its app bar, and one
mini player above the bottom nav controls whatever is being read — including
after you have navigated somewhere else entirely. That is the whole design
constraint: a reading survives navigation, so its controls have to live in
`HomeShell`, the only widget that outlives every route.

There is one engine, in `speechProvider`. Screens never touch `FlutterTts`.

```
features/speech/
  speech_chunk.dart      SpeechChunk and Speakable — one utterance, and a queue
  speakables.dart        the only place that knows how a card or a chapter reads
  speech_controller.dart the engine, the queue, and the settings
  speech_voices.dart     the voice list, filtered and grouped
  listen_button.dart     the app-bar control
  speech_bar.dart        the transport, docked above the bottom nav
  speech_settings_sheet.dart  voice, speed and reach — shown in More and as a sheet
```

Four things are worth knowing before changing any of it:

1. **The queue is driven by the completion handler, not by awaiting `speak`.**
   That is what lets pause, skip and stop land immediately rather than at the
   end of the current chunk. Stale callbacks are filtered by a generation
   counter, because the engine delivers completions for utterances that were
   already cancelled — without the guard, stopping starts the next chunk.
2. **Resume means speaking the same string again.** Both platforms treat that
   as "continue": iOS calls `continueSpeaking`, Android picks the utterance back
   up from the word it paused on. Passing a different string restarts it.
3. **Rate is a multiplier, not an engine value.** 1.0 is normal on both
   platforms. `SpeechController` asks the engine for its own valid range and
   maps onto it; do not pass a raw number through.
4. **Android needs the `TTS_SERVICE` query.** Since Android 11 an app sees only
   the packages it declares an interest in, and the speech engine is another
   package. `android/app/src/main/AndroidManifest.xml` declares it; flutter_tts
   does not. Remove it and every Listen button goes quiet with no visible error.

The reading keeps going when the app is not on screen, and appears on the lock
screen. `SpeechAudioHandler` wraps the *same* `SpeechController` the mini player
drives, so the notification and the app cannot disagree. That costs three pieces
of native setup, all of which are load-bearing:

- `MainActivity` extends `AudioServiceActivity`, so the service and the UI share
  one `FlutterEngine`. With a plain `FlutterActivity`, audio_service starts a
  second engine and the notification drives a queue the app cannot see.
- The service, the media-button receiver and `FOREGROUND_SERVICE_MEDIA_PLAYBACK`
  are declared in the manifest.
- `UIBackgroundModes: audio` is in the iOS `Info.plist`.

`androidStopForegroundOnPause` is **false** on purpose. Since Android 12 an app
cannot restart a foreground service from the background, so tearing it down on
pause makes the lock screen's play button throw instead of resuming. The cost is
that the notification stays while paused, which is what every audiobook app does.

A sleep timer lives in the same controller. When it fires mid-utterance the
reading finishes the line it is on and stops there, rather than cutting off in
the middle of a verse.

Anchors are the join between what is being said and what is on screen.
`Speakables` gives each chunk one, `PassageView` marks and scrolls to the verse
it names, and `WonderCardBody` tints the section. If you add a chunk, give it an
anchor the view already knows, or the reading and the highlight drift apart.

`test/features/speech/` covers the chunking and the voice list — both are pure
functions, and both fail in ways you would otherwise only find by listening to a
whole chapter.

## Kept verses

Press and hold any verse to mark it. One sheet does the whole feature: pick a
colour to keep it, tap that colour again to let it go, add a note if there is
something to say. `More → Kept verses` lists them, newest first, and a tap goes
back to the chapter.

A mark **is** both the bookmark and the highlight. Two concepts would have meant
two gestures and two lists to explain, for a distinction nobody asked to make —
so colouring a verse is what saves it.

They live in `library.db`, deliberately not in `bible.db`. That file is opened
read-only and is replaced wholesale whenever `npm run flutter:assets` rebuilds
it, so a verse somebody marked would be thrown away by a future text
correction. Scripture ships with the app; what the reader makes of it is theirs.

Every mark is held in memory by `LibraryController` and looked up through
`marksInChapterProvider`. The reader draws one decoration per verse per frame,
so that lookup has to be a map read rather than a query — the same reasoning
that keeps 178 wonders in memory and the Bible in SQLite.

`library.db` survives a text correction, but it does not survive uninstalling
the app or changing phone, so `LibraryExport` writes the list to a readable text
file and hands it to the share sheet. It is an export, not a backup: reading one
back would need a file picker this app does not otherwise want, and a list you
can mail to yourself is worth more than a blob only this app can open. If import
is ever added, that is the moment to change the format.

## The footer on the More tab

`features/settings/maker_footer.dart` is a port of the website's own
`.social-icons` row — from
`amsterdam-metro-v2/frontend/src/components/SocialIcons.tsx` and the rules in
its `index.css`, not a new design. One flex line, `flex: 1 1 0` per item so nine
marks spread across any width, bare glyphs at 1.35rem with no ring, 88% opacity
lifting to full and a 1px rise on touch.

Both of this app's themes are dark, so the stylesheet's `.dark` rules are the
ones in force: X, GitHub, Medium and TikTok are white here, not the `#000` they
take on a light page. Three marks are not one flat colour — Instagram's 45°
gradient is a `ShaderMask`, TikTok's `text-shadow` split is two offset copies
behind the glyph, and `fa-globe` has no colour of its own so it keeps the
inherited grey. The URLs are copied from that component rather than rebuilt from
handles; several are not the obvious form and YouTube's is a channel id.

## A note on grids

`gridTileExtent` in `theme/metrics.dart` exists because a hard-coded
`mainAxisExtent` is a RenderFlex overflow waiting for somebody to raise their
system font. The era picker was already overflowing at the default size: "Acts
and the early church" wraps to two lines, and `Card`'s own 4pt margin took eight
points off the height before the padding came out. Grids measure now. If you add
one, pair `titleLines` with a matching `maxLines` on the Text — otherwise a long
label finds a third line and overflows anyway.

## What is still scaffold

- **The tour** (`features/tour/`) walks the ranked shortlist, not the curated
  fourteen in the website's `lib/miraclesTour.ts`. Export that alongside the
  catalog and read it here. Narration itself is done — the tour reads each
  step, and will read them automatically if asked.
- **Riverpod is held at 2.6.1.** Version 3 needs a Dart floor above the
  `^3.6.0` this project declares, and the migration is not small: every provider
  here is a `StateNotifier`, which v3 deprecates. Raising the floor would drop
  Flutter 3.27–3.34. Deliberate, not neglect — see the note in `pubspec.yaml`.

## Branding

One source picture: `branding/app-icon.png`, the same file the website serves as
`public/icon-512.png`. Change that and re-run the three commands from **First
run**; everything else is derived, and both `adaptive-foreground.png` and
`splash-icon.png` beside it are gitignored for that reason.

`#163D2F` is the picture's own ground, and it is also `Palette.pine.shade800` —
the icon was cut from the same palette the app wears in the Old Testament. So
the launcher icon, the splash and the first screen are one continuous colour,
and the app appears to open rather than to cut. If the artwork is ever replaced,
`tool/make_branding.dart` prints the new ground colour; put it in both
`flutter_launcher_icons` and `flutter_native_splash` in `pubspec.yaml`.

The tool exists because the two consumers inset differently, and one file cannot
be right for both:

| Output | Mark size | Why |
| --- | --- | --- |
| `adaptive-foreground.png` | 62% | `flutter_launcher_icons` adds its own 16% inset, then the launcher mask keeps the central 66% — landing at ~64% of the visible icon. |
| `splash-icon.png` | 45% | The Android 12 splash adds no inset and draws into a 240dp circle whose safe area is the inner 160dp. |

Handing the source picture straight to either would let a circular mask shave
the book's edges: it spans about 76% of its own canvas.

Nothing under `branding/` ships as a Flutter asset. All three packages are
`dev_dependencies` that write native resources at setup time and are not linked
into the app.

The splash needs no Dart. `main()` already resolves prefs, the catalog and the
database before `runApp`, so the native splash stays up until the first real
frame — there is no blank gap to cover and no `FlutterNativeSplash.preserve`
call to make.

## Tests

```bash
flutter test
flutter test --update-goldens   # after an intended ShareCard change
```

`test/features/share/share_card_test.dart` is the important one. It pins the
content rule — the fixture's prose fields are filled with `SECRET_…` markers and
the test fails if any of them reach the image — alongside a golden per palette.

Note what the goldens do and do not prove. `flutter test` has no Google Fonts, so
they render in the test placeholder face and the images are blocks, not words:
they catch layout, sizing and palette regressions, not typography. The content
and layout assertions in the same file are what cover the rest.

`test/features/speech/speakables_test.dart` pins what read-aloud actually says —
that the quote is read before its reference, that a chapter does not speak its
verse numbers, and that a wonder's passage starts on the verse the card cites.

`test/data/wonders_search_test.dart` and `test/catalog_browsing_test.dart` run
against the real generated `wonders.json`, deliberately — the search bug they
cover was a disagreement between the code and the actual catalog, and a
hand-written fixture would have agreed with the broken code.
