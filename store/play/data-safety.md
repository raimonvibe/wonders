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

## Target audience

Not directed at children. Select the adult age bands. Declaring a child audience
would pull the app into Families policy and require a content review it does not
need.
