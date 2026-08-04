# Google Play — Wonders and Hope

Assets for the Play Console listing live under `store/play/`.
The signed upload bundle is built with:

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

## Upload signing

Release builds are signed with `android/upload-keystore.jks` when
`android/key.properties` is present (both are gitignored).

Credentials are in `android/keystore-credentials.txt` (local only).
**Back that file and the `.jks` up somewhere safe.** Losing the upload key
blocks updates unless you use Play App Signing and ask Google to reset it.

In Play Console → App integrity, enrol **Play App Signing** and upload this
AAB; Google re-signs with the app signing key.

## Listing assets (ready)

| Asset | Path | Spec |
| --- | --- | --- |
| High-res icon | `store/play/graphics/icon-512.png` | 512×512 PNG |
| Feature graphic | `store/play/graphics/feature-graphic-1024x500.png` | 1024×500 PNG |
| Phone screenshots (raw) | `store/play/screenshots/phone/*.png` | 1280×2856 PNG (8) |
| Phone screenshots (diagonal, full device) | `store/play/screenshots/diagonal/*.png` | 1080×2340 PNG (8) |
| Phone screenshots (half-cut sequence) | `store/play/screenshots/half-cut/*.png` | 1080×2340 PNG (8) |

Play requires **at least 2** phone screenshots. Prefer the **half-cut** set for the listing — upload in order 01→08 so the alternating tilts read as one sequence.

### Half-cut sequence (upload these, in order)

| # | File | Label |
| --- | --- | --- |
| 1 | `01-browse-wonders.png` | Browse 178 wonders |
| 2 | `02-wonder-card.png` | Each wonder, told clearly |
| 3 | `03-passage-beside.png` | Passage open beside you |
| 4 | `04-bible-books.png` | The whole Bible |
| 5 | `05-bible-reader.png` | Read without distraction |
| 6 | `06-guided-tour.png` | A guided tour |
| 7 | `07-listen-and-keep.png` | Listen, keep, share |
| 8 | `08-pick-a-chapter.png` | Pick a chapter |

Also available: full-device diagonals in `screenshots/diagonal/`, raw flats in `screenshots/phone/`.

## Suggested store text

**App name (30 chars):** `Wonders and Hope: Bible`

> This is the *store listing* title and is deliberately not the same as the
> launcher label, which is `Wonders` (`android/app/src/main/res/values/strings.xml`
> and `CFBundleDisplayName`). A launcher gives an icon about ten to twelve
> characters before it ellipsizes, so the full name arrived as "Wonders and…".
> The two fields are unrelated — do not "fix" the mismatch.
>
> The `: Bible` is there to be searched for. The title is the strongest signal
> Play's search has, and neither "Bible" nor "miracles" appeared anywhere in
> it. 23 of the 30 characters, which leaves room and stays well clear of
> keyword stuffing.

## Package name — settled, and permanent

`com.raimonvibe.wonders`, on both platforms.

Chosen before the first upload, which was the only moment it could be: an
`applicationId` cannot be changed once an app is published. Renaming after
that means a new listing, and the reviews, installs and ratings do not come
with it.

It replaced `com.raimonvibe.bible_wonders` on Android and
`com.raimonvibe.bibleWonders` on iOS — which had drifted apart from each
other, and would have gone on drifting.

Not to be confused with the Dart package name in `pubspec.yaml`, which is
still `bible_wonders` and has to stay: every `package:bible_wonders/…` import
in `test/` resolves through it, and it is invisible outside the repository.

**Short description (80 chars):**
`178 Bible wonders and miracles — each with the passage open beside you.`

> 71 of the 80. The spare characters went on "miracles" rather than on
> decoration: Play indexes the title, the short description and the full
> description for search, and that word appeared in none of them.
>
> **No emoji anywhere in this listing.** In the title they are not allowed —
> Play's metadata policy bars emoji, emoticons and repeated special characters
> from the title, icon and developer name. In the descriptions they are
> allowed, and are still wrong here: a screen reader announces an emoji by
> name, and this is an app whose central feature is reading aloud and whose
> code carries a `semanticFormatterCallback` so that a blind reader does not
> hear "one point four". They also earn no search weight while costing
> characters, at 2 or more apiece. The em dash is not an emoji and is fine; so
> are the `•` bullets below, which are structural.

**Full description:**
```
Wonders and Hope brings the Bible's miracles to your phone — and opens
the chapter they happened in right beside the card.

• 178 wonders across both Testaments
• Paths to browse: Start here, by theme, by era, or the full catalog
• Swipe from a wonder's card to its passage — without losing your place
• Full Bible reader (World English Bible)
• Listen aloud, including on the lock screen
• Keep verses with a colour and a note
• Share a wonder as a clean quote image

Built for quiet reading, not for noise.
```

## Release notes ("What's new")

500 characters per language, one `<xx-XX>` block each. Play does not translate
them; an `en-US` block is shown everywhere, which is the whole of it — see
"Countries" below.

**Emoji are allowed here**, unlike in the title, where Play's metadata policy
bars them outright. Two or three, not a scatter: the notes are read aloud by a
screen reader like everything else, and this app does not shout. See the note
under the short description for the fuller reasoning.

The offline line earns its characters. It is the app's least ordinary property
and the only claim on the listing the system itself enforces — there is no
`INTERNET` permission, so it cannot be quietly untrue one release later.

### Closed testing

```
<en-US>
📖 The first build of Wonders and Hope.

178 of the Bible's miracles, each with the passage open right beside it.

• Browse by theme, era, or take the guided tour
• The whole Bible (World English Bible)
• Listen aloud, even with the screen off 🎧
• Keep verses with a colour and a note
• Share a wonder as a quote image

Works fully offline. No account, no ads, nothing collected.

Thank you for testing — tell me anything that feels off. 🙏
</en-US>
```

441 characters.

### Production

```
<en-US>
📖 The first release of Wonders and Hope.

178 of the Bible's miracles, each with the passage open right beside it.

• Browse by theme, era, or take the guided tour
• The whole Bible (World English Bible)
• Listen aloud, even with the screen off 🎧
• Keep verses with a colour and a note
• Share a wonder as a quote image

Works fully offline. No account, no ads, and nothing about you leaves your phone.
</en-US>
```

417 characters.

## Countries

All available, on every track.

The listing is `en-US` only and stays that way. Play shows it as written
wherever the app is available rather than translating it, so a reader in Japan
sees English — which is the right outcome here, because the app is English
only: the World English Bible is the one text it ships.

Countries and pricing are set **per track**. Setting production to every
country does not apply to the closed test, or the other way round. Check both.

## Console checklist

Everything below is prepared except the four that need a browser or a decision.

- [ ] Create app in Play Console (`com.raimonvibe.wonders`)
- [ ] **Enrol in Play App Signing** — do this at first upload. It is the only
      recovery path for a lost upload key and cannot be added afterwards.
- [ ] Upload `store/play/upload/app-release.aab` to a closed testing track
      first — `1.0.0+3`, signed and verified, see **Version** and **Signing**
- [ ] Invite testers → `tester-invite.md`. A personal developer account needs
      **12 testers opted in for 14 continuous days** before production access
      is granted, counted on testers still enrolled rather than invited
- [ ] Attach icon, feature graphic, and the half-cut screenshots (01→08)
- [ ] Paste app name, short + full description (above)
- [ ] Paste release notes → **Release notes**, above. Use the closed-testing
      block for the test track and the production block for production; they
      differ by two lines and the difference matters to whoever reads them.
- [ ] **App access** (*App-toegang*) → "All functionality is available without
      any access restrictions". Leave the credentials box **empty**. There is no
      login, no paywall, no region lock and no network, so a reviewer sees the
      whole app on first launch. Easy to miss precisely because the answer is
      nothing — do not fill the box "just in case", it invites a reviewer to
      hunt for a sign-in screen that does not exist
- [x] **Content rating questionnaire** → done 4 August 2026. Everyone / PEGI 3
      / all ages everywhere, **no content descriptors**. Every answer and the
      reasoning behind it is in `data-safety.md`, including the rating table, so
      the next submission is a transcription rather than a re-derivation
- [x] **Target audience** → **13-15, 16-17, 18+**. Nothing under 13. Earlier
      drafts of this file said "adult bands", which reads as 18-only and is
      wrong — see `data-safety.md`
- [x] **Data safety form** → done. The store card reads "No data collected"
      and "No data shared with third parties". Answers and evidence in
      `data-safety.md`
- [x] **Privacy policy hosted** at
      <https://privacy-policy-wonders-and-hope.vercel.app/> — paste that URL
      into the Console's designated field. The page's source is `index.html` in
      the repository root; edit and redeploy it there. Fetched and checked on
      4 August 2026: it loads, names the app and the publisher, says the app
      collects nothing, covers text-to-speech, carries a contact address and is
      dated. Worth re-fetching before each submission — Play rejects a dead
      link, and a policy URL is the easiest thing in a listing to stop
      noticing.
- [x] **Privacy policy inside the app** — More → Privacy policy, linking to the
      same URL. Play asks for it in *both* places and the in-app half is the one
      people miss: *"All apps must post a privacy policy link in the designated
      field within Play Console, and a privacy policy link or text within the app
      itself."* It is not conditional on collecting data — the same policy says
      apps that access no personal data must still have one.
- [ ] Foreground service declaration: `mediaPlayback`, justified as
      "spoken-word playback of scripture with lock-screen controls"
- [ ] Countries / pricing (free) → all available, **per track** — see
      **Countries**, above

## Signing — settled

The upload key is `Documents/keys2/upload-keystore.jks`, alias `upload`,
PKCS12, valid to 2053. `android/key.properties` points at it; see
`android/key.properties.example` for the fingerprint and how to verify a build.

The bundle in `upload/` is signed with it — confirmed, not debug-signed.
Rebuilt 4 August 2026 under `com.raimonvibe.wonders`; the one before that
carried the old package name and could not have been uploaded.

Verified at build time rather than assumed:

```
Owner:   CN=Wonders and Hope, OU=Mobile, O=Raimonvibe, L=Amsterdam, ST=NH, C=NL
SHA-256: F7:98:A5:4E:37:49:53:92:93:90:8A:22:33:76:0B:00:
         B8:AE:55:B0:E7:DE:A2:9C:38:A3:A2:3A:DA:21:78:1D
package  com.raimonvibe.wonders   versionCode 3   versionName 1.0.0
```

The fingerprint matches the one recorded in `android/key.properties.example`.
An `Owner` of `CN=Android Debug` would have meant `key.properties` was missing
and Gradle had fallen back to debug signing — silently, producing a
normal-looking bundle that Play rejects.

**Back up that .jks and its password in two places before you upload anything.**

## Version

`pubspec.yaml` is at **1.0.0+3** (`versionName` / `versionCode`).

Play rejects a `versionCode` it has already seen, so the bump is per *upload*,
not per release — a rejected or replaced bundle still burns its number. Bump
the build number every time; bump the `versionName` only when the release is
one users should be able to tell apart.

The first upload is `1.0.0+n` rather than `1.0.1+n`: `versionName` is what a
user sees, and shipping the first release as 1.0.1 says a 1.0.0 existed. The
build number left 1 behind because that bundle was built under the old package
name, and has moved on since — a versionCode costs nothing and there are two
billion of them, so bumping when in doubt is always cheaper than discovering at
the Console that Play has seen the number before.
