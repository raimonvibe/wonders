# Play Console — Data safety answers

The form is a declaration you sign, so the wording matters. These are the
answers that match what the app actually does; the reasoning is here so a future
release can be checked against it rather than guessed at again.

## Data collection and sharing

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data encrypted in transit? | n/a — no user data leaves the device |
| Do you provide a way for users to request that their data is deleted? | n/a — uninstalling removes everything |

"Collect" in Play's definition means transmitting data off the device. The app
transmits nothing: no account, no analytics, no advertising, no crash reporting,
no server of its own.

Kept verses, notes, reading position and settings are stored in the app's
private storage and are **not** collected under this definition. Play is
explicit that on-device-only processing is not collection.

## The network calls: there are none

The app **holds no `INTERNET` permission**. It cannot open a connection, which
is a stronger answer to every question on this form than any promise about
conduct.

This changed on 3 August 2026. Until then the note here read that Inter,
Merriweather and Playfair Display were fetched from Google Fonts on first use —
the one call the app made. The three families now ship in `assets/fonts/` with
`GoogleFonts.config.allowRuntimeFetching = false`, which is the suggestion this
file used to carry, and `INTERNET` came out of the manifest with them. Checked
against the merged manifest: no plugin in this tree declares it, so removing it
from `android/app/src/main/AndroidManifest.xml` removes it.

**url_launcher.** Opens the developer's own links from the More screen, only
when tapped. It hands the address to the browser through an Intent; the browser
holds the permission and does the visiting. Nothing is transmitted by this app,
and it could not transmit anything if it tried.

## Text to speech

Reading aloud passes text to the device's own TTS engine. On devices configured
with a network voice, that engine may send the text to its own provider — but
that is the platform's behaviour under the user's own speech settings, not this
app's, and the app receives only audio. Declare nothing; the privacy policy
explains it.

## Permissions to justify in the console

| Permission | Why |
| --- | --- |
| `POST_NOTIFICATIONS` | Playback controls while a passage is read aloud |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Keeps the reading running off screen; Play asks for a justification video or description — "spoken-word playback of scripture with lock-screen controls" is the sanctioned use |
| `WAKE_LOCK` | Required by audio_service for uninterrupted playback |
| `<applicationId>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | Nothing to justify. AndroidX generates it because audio_service registers a receiver at runtime; it is `signature`-level and scoped to this package, so no other app can hold it and no user is ever asked for it. It appears in the Console's permission list — expect it rather than go looking for what added it. |

`INTERNET` is **not** requested. It used to be, for the font fetch; see above.

## Verified against the release build, not the source

Read out of the built artifact on 4 August 2026, because a claim signed on a
form should be checked against what ships rather than against what the manifest
appears to say:

```
$ aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk
package: name='com.raimonvibe.wonders'
application-label:'Wonders'
uses-permission: name='android.permission.WAKE_LOCK'
uses-permission: name='android.permission.FOREGROUND_SERVICE'
uses-permission: name='android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'
uses-permission: name='android.permission.POST_NOTIFICATIONS'
uses-permission: name='com.raimonvibe.wonders.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'
```

No `INTERNET`. That is the whole of it, merged manifest included.

**A debug or profile build will show `INTERNET`, and that is not a problem.**
`android/app/src/debug/AndroidManifest.xml` and `android/app/src/profile/`
each add it so the Flutter tool can reach the running app for hot reload. Only
the release manifest reaches Play. Anyone checking this claim against an APK
built from the IDE will find the permission and think this file is wrong — it
is not; check `app-release.apk`.

Worth repeating at each release, since it is one command:

```bash
flutter build apk --release
aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | grep uses-permission
```

## Two things the form does not ask about, and why

**share_plus.** Sharing a wonder as an image hands data to another app. It is
user-initiated, the target is chosen by the user in the system sheet, and
nothing is transmitted by this app. Not collection; declare nothing.

**No analytics, ads or crash reporting.** The full dependency list is riverpod,
go_router, sqflite, path, path_provider, shared_preferences, flutter_tts,
audio_service, share_plus, google_fonts, url_launcher, font_awesome_flutter and
scrollable_positioned_list. Nothing there phones anywhere, and without
`INTERNET` nothing could.

## Content rating

Answer the questionnaire honestly and the app lands at **Everyone / PEGI 3**:
no sexual content, no profanity, no gambling, no user-generated content, no
communication between users, no purchases, no ads, no location sharing.

Whether religious content needs declaring: it does not. The questionnaire has
no such category, and public-domain scripture is not "sensitive content" in
Play's sense.

**Violence is the one answer not to give by reflex.** This file used to say
"no violence" flatly, and that is not quite true of the material: the app
carries scripture in which Pharaoh's army drowns, and the Red Sea card says so
in as many words — "The same waters that opened for Israel closed again over
the army chasing them."

IARC's violence questions are about *depictions* — graphic, realistic,
interactive, on screen. Non-graphic narrative in a religious text is not what
they are asking about, which is why Bible apps sit at Everyone / PEGI 3 as a
matter of course. So the answer is almost certainly still no.

But if the questionnaire offers a non-graphic or textual-reference option,
take it. A rating that comes back one band higher costs nothing. A
misdeclaration found later is grounds for removal, and the questionnaire is
signed under the same declaration as the data safety form.

**How to decide, at the question itself.** IARC's wording is the deciding
thing, and the Dutch console phrases it as *geweld*:

- If it asks whether the app **contains or depicts** violence — showing it,
  drawing it, animating it, letting the user do it — the answer is **no**.
  This app renders text. It has no artwork of violence, no animation and
  nothing interactive.
- If it asks whether the app **refers to** violence, or offers a "non-graphic"
  or "textual" band, answer **yes at the mildest option available**. Scripture
  narrates the Egyptian army drowning, and the Red Sea card says so.

Answering an unqualified yes to a depiction question over-declares. It is not
dishonest and Play will not punish it, but the rating comes back at a band a
scripture reader has no reason to carry, which narrows the audience and reads
oddly on the listing. Bible apps sit at Everyone / PEGI 3 as a matter of course.

**Other questions in the same section, for the record:** offensive language
(*aanstootgevend taalgebruik*) — **no**; the World English Bible contains no
profanity in the modern sense. Sexual content, nudity, drugs, gambling,
horror, user interaction, location sharing, purchases — all **no**.

**Nothing here is final.** The questionnaire can be retaken in the Console at
any time and the rating is regenerated from the new answers. A rating that
comes back wrong is a form to fill in again, not a submission to withdraw.

### The rest of the questionnaire, answered

Category: **Alle andere typen apps** / All other app types. Not a game.

| Question | Answer | Why |
| --- | --- | --- |
| A built-in feature letting users interact or exchange content with **other users** — voice, text, images, audio | **No** | The words that decide it are "built-in" and "other users": chat, comments, profiles, a shared feed. There are none. `share_plus` hands an image to the *system* share sheet and Android decides where it goes; the recipient is whoever the user picked, in another app. If a share button counted, every app with one would answer yes. |
| Shares the user's precise physical location with other users | **No** | No location permission in the release manifest, and no `INTERNET` to share over. |
| Lets users buy digital products | **No** | No billing dependency. The app is free and nothing is gated. |
| Money rewards, gift cards, play-to-earn, crypto-convertible rewards, transferable digital assets (NFTs) | **No** | None of it. The follow-up checkboxes stay empty; they only appear if this is yes. |
| A web browser or search engine | **No** | The app searches its own bundled catalogue and a local SQLite database. The question means general-purpose *web* browsing and search, which requires a network this app does not have. |
| Primarily a News or Educational product | **No** | The word doing the work is *primarily*. This is a scripture reader with a curated catalogue — no lessons, no exercises, no progression, no assessment. Its Play category is Books & Reference. |

Answering yes to the user-content question is the one that would genuinely cost
something. It gates Play's user-generated content policy, which requires a
moderation approach, an in-app reporting mechanism and a way to block abusive
users — real obligations, for content that cannot exist here. Unlike the
violence question, where a higher band costs nothing, over-declaring is not the
safe hedge.

"Educational" is a defensible yes and still the wrong answer: it nudges the app
toward the Teacher Approved programme and family expectations, which contradicts
the adult target audience declared on the other form. Two answers pointing in
different directions attract a reviewer's attention for no benefit.

### The rating that came back

4 August 2026, first submission, **no content descriptors in any region**:

| Region | Body | Rating |
| --- | --- | --- |
| Brazil | ClassInd | All ages |
| North America | ESRB | Everyone |
| Europe | PEGI | PEGI 3 |
| Germany | USK | All ages |
| Rest of world | IARC Generic | 3+ |
| Russia | Google Play | 3+ |
| South Korea | Google Play | 3+ |

The empty descriptor column is the part worth keeping. It says IARC found
nothing in the app needing a warning, which retires the violence question above
for good — not by argument, but by result.

The South Korea note about GRAC applies to games. This is not one.

## App access

*App-toegang*, alongside the forms above. Answer: **all functionality is
available without any access restrictions**, and the credentials box stays
**empty**.

There is no login, no paywall, no region lock and no network, so a reviewer
installing the bundle sees the whole app on first launch. The box exists so
reviewers can reach what is hidden behind a sign-in; describing restrictions
that do not exist invites one to hunt for a screen that is not there.

It is easy to miss precisely because the correct answer is nothing at all.

## Target audience

Not directed at children. Select the adult age bands. Declaring a child audience
would pull the app into Families policy and require a content review it does not
need.
