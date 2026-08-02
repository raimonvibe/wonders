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

## The two network calls, and why neither is collection

**Google Fonts.** Inter, Merriweather and Playfair Display are fetched on first
use and cached. This sends a request for a font file. No user data is attached.
Declare nothing; mention it in the privacy policy, which
`store/play/privacy-policy.md` does.

> If you would rather the app made no network call at all, bundle the three
> families as assets and set `GoogleFonts.config.allowRuntimeFetching = false`.
> That is the cleaner story for an app whose whole premise is offline reading,
> and it costs a couple of megabytes.

**url_launcher.** Opens the developer's own links from the More screen, only
when tapped, and hands off to the browser. Nothing is transmitted by the app.

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
| `INTERNET` | Merged in by plugins; used only for the font fetch and for opening links |

## Content rating

Answer the questionnaire honestly and the app lands at **Everyone / PEGI 3**:
no violence, no sexual content, no profanity, no gambling, no user-generated
content, no communication between users, no purchases, no ads, no location
sharing.

The one question worth pausing on is whether religious content needs declaring.
It does not — the questionnaire has no such category, and public-domain
scripture is not "sensitive content" in Play's sense.

## Target audience

Not directed at children. Select the adult age bands. Declaring a child audience
would pull the app into Families policy and require a content review it does not
need.
