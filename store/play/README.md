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

**App name (30 chars):** `Wonders and Hope`

> This is the *store listing* title and is deliberately not the same as the
> launcher label, which is `Wonders` (`android/app/src/main/res/values/strings.xml`
> and `CFBundleDisplayName`). A launcher gives an icon about ten to twelve
> characters before it ellipsizes, so the full name arrived as "Wonders and…".
> The two fields are unrelated — do not "fix" the mismatch.

**Short description (80 chars):**
`178 Bible wonders — each with the passage open beside you.`

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

## Console checklist

Everything below is prepared except the four that need a browser or a decision.

- [ ] Create app in Play Console (`com.raimonvibe.bible_wonders`)
- [ ] **Enrol in Play App Signing** — do this at first upload. It is the only
      recovery path for a lost upload key and cannot be added afterwards.
- [ ] Upload `store/play/upload/app-release.aab` to a closed testing track first
- [ ] Attach icon, feature graphic, and the half-cut screenshots (01→08)
- [ ] Paste short + full description (below)
- [ ] Content rating questionnaire → answers in `data-safety.md`
- [ ] Target audience: adult bands, not child-directed → `data-safety.md`
- [ ] Data safety form → answers in `data-safety.md` (short version: collects
      nothing)
- [ ] **Host `privacy-policy.md` somewhere public** and paste the URL. This is
      the one remaining hard blocker; raimonvibe.eu or a GitHub Pages file will
      do.
- [ ] Foreground service declaration: `mediaPlayback`, justified as
      "spoken-word playback of scripture with lock-screen controls"
- [ ] Countries / pricing (free)

## Signing — settled

The upload key is `Documents/keys2/upload-keystore.jks`, alias `upload`,
PKCS12, valid to 2053. `android/key.properties` points at it; see
`android/key.properties.example` for the fingerprint and how to verify a build.

The bundle in `upload/` is signed with it — confirmed, not debug-signed.

**Back up that .jks and its password in two places before you upload anything.**

## Version

`pubspec.yaml` is at **1.0.0+1** (`versionName` / `versionCode`).
Bump both before each Play upload (`1.0.1+2`, etc.).

Play rejects a `versionCode` it has already seen, so the bump is per *upload*,
not per release — a rejected or replaced bundle still burns its number.
