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

- [ ] Create app in Play Console (`com.raimonvibe.bible_wonders`)
- [ ] Upload `app-release.aab` to a production / closed testing track
- [ ] Attach icon, feature graphic, and phone screenshots
- [ ] Paste short + full description
- [ ] Content rating questionnaire
- [ ] Target audience / news apps declarations
- [ ] Data safety form (marks and prefs stay on-device; no account)
- [ ] Privacy policy URL (required for many apps — host a short page)
- [ ] Declare foreground service type: mediaPlayback (read-aloud)
- [ ] Countries / pricing (free)

## Version

`pubspec.yaml` is at **1.0.0+1** (`versionName` / `versionCode`).
Bump both before each Play upload (`1.0.1+2`, etc.).
