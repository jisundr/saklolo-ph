# Saklolo

An emergency voice assistant for iPhone, built for the AppBuildersPH Hackathon 2026 (theme: Local AI, solo entry).

## What it is

Tap the red button and say what happened in Taglish. Saklolo works out what happened on the phone, alerts your circle by SMS with a summary and your GPS location, and then shows vetted first-aid steps one at a time to whoever is there until help arrives. The AI needs no data: speech recognition, understanding and guidance all run on the device. It does not contact 911 on its own (the guide has a Call 911 button you tap yourself), and the SMS and calls still need cell signal.

## Why local AI

Emergencies happen where there is no data: inside homes with weak signal, during typhoons, in the provinces, on prepaid load with no data promo. Speech recognition, understanding the situation, and first-aid guidance must work instantly without data, so they run on the phone. Only SMS and calls use the cell network. Local also means no audio from inside someone's home goes to a server, and it costs nothing per use. One caveat, stated plainly: the speech model is downloaded once on first launch (see [What runs locally](#what-runs-locally-and-what-needs-the-network)).

## How it works

1. Tap the red button, then say what happened in Taglish (for example "Tulong! Nahulog si Lola").
2. WhisperKit transcribes the speech on the phone.
3. Apple Foundation Models classifies the transcript into one of four scripts (bleeding, fall, head injury, unconscious) or a general one, and chooses alone mode or guide mode. If the model is unavailable or too slow, bundled keyword rules (`keywords.json`) do it instead.
4. One alert goes out at the end of understanding, no later than 10 seconds after the tap. If nothing was understood, a general text is sent. Cancelling before it fires sends nothing.
5. The alert is sent through an Apple Shortcut named "Saklolo", with the GPS location in the text, and the app then dials contact #1. The app says contacts were told only after the Shortcut reports success. Otherwise it shows a card with a button that opens the system message composer.
6. Guide mode shows the steps of the matching script one at a time, with Next, Back and Repeat. The steps are not read aloud yet.

The language model only classifies. It never writes first-aid text: every step comes from the bundled JSON scripts in `Saklolo/Resources/Scripts`, which cite the IFRC International First Aid, Resuscitation, and Education Guidelines 2020 (Red Cross Red Crescent).

## Build and run

Requirements: a Mac with Xcode, [Homebrew](https://brew.sh), and an iPhone for the full flow. The app targets iOS 17.0, iPhone only, Swift 6.

```sh
git clone https://github.com/jisundr/saklolo-ph.git
cd saklolo-ph
brew install xcodegen
xcodegen generate
open Saklolo.xcodeproj
```

Then in Xcode:

1. Select the Saklolo target, open Signing & Capabilities, and pick your own team. No team is pinned in `project.yml`. A free Personal Team works for a device install (the profile lasts 7 days).
2. Select your iPhone (or an iPhone simulator) and press Run. Swift packages (WhisperKit) resolve on first open and need network.
3. Allow Microphone and Location When In Use when asked.

### Create the "Saklolo" Shortcut (setup step, on the phone)

The app can only open a Shortcut, it cannot create one: iOS shows its own "Add Shortcut" screen for any import. In the Shortcuts app, create a shortcut named exactly `Saklolo` that:

1. receives text as its Shortcut Input. The app passes JSON: `{"to": ["+639171234567", "..."], "text": "SAKLOLO: ..."}`,
2. runs Get Dictionary from Input, then Send Message (Show When Run off) with the text from the key `text`, to the numbers from the key `to`.

The Shortcut holds no contacts, so the numbers entered in the app are the ones texted, the same ones used for the call and the fallback composer. If you built the old plain-text Saklolo Shortcut, replace it with this one: the old one would text the raw JSON to your contacts. Once a signed copy is shared, set `ShortcutInstaller.shareURL` to its iCloud link and setup shows an "Add the Saklolo Shortcut" button.

The app then opens `tel://` for contact #1 on its own. The Shortcut reports back to the app through `saklolo://alert/<id>/<sent|failed|cancelled>`.

### First launch

The speech model is not bundled. It downloads once (about 632 MB, needs network), is cached on the phone, and the first preparation takes about 3 minutes (CoreML compile; about 10 seconds on later launches). The app never blocks on it: Home shows the model status, and the red button and the alert work meanwhile.

### Tests

```sh
xcodebuild -scheme Saklolo -destination 'platform=iOS Simulator,name=<an iPhone simulator>' test
```

The 167 unit tests pass on the iPhone 15 Pro Max (iOS 27) device and on its simulator.

### Simulator versus a real iPhone

- Simulator: you can see the UI, setup, Home, the Listening and Guide screens, and run the tests. It cannot send SMS or place calls and has no on-device language model, so the keyword fallback is used.
- Real iPhone with a SIM: the full flow (SMS through the Shortcut, the call, GPS). The Foundation Models classifier needs iOS 26+ with Apple Intelligence turned on.

## What runs locally and what needs the network

| Part | Where | Network |
| --- | --- | --- |
| Speech-to-text (WhisperKit) | On the phone | One-time model download on first launch (about 632 MB); none afterwards |
| Situation classification (Apple Foundation Models, keyword fallback) | On the phone | None |
| First-aid guidance (bundled JSON scripts) | On the phone | None |
| GPS (CoreLocation) | On the phone | None |
| SMS and calls | Carrier | Cell network, not data |

Airplane-mode behaviour with a cached model has not been verified (spike 004b is open).

## Disclosures

- Models: Whisper large-v3 turbo (`openai_whisper-large-v3-v20240930_turbo_632MB`) through WhisperKit; Apple Foundation Models (`SystemLanguageModel`) where available.
- Frameworks: SwiftUI, WhisperKit (argmax-oss-swift 1.1.1), Foundation Models, CoreLocation, Apple Shortcuts (x-callback-url), XcodeGen for project generation.
- APIs and cloud services: none for the AI. The one network call the app makes is the model download on first launch (fetched by WhisperKit; the host is not documented here). SMS and calls go over the carrier network.
- Existing code and assets: first-aid content follows the IFRC International First Aid, Resuscitation, and Education Guidelines 2020; Barlow Condensed font (SIL OFL, `Saklolo/Resources/Fonts/OFL.txt`); no pre-starter code is listed in the docs.
- AI development tools: Claude Code.

## Known limits

- Checked on a real iPhone with the earlier plain-text Shortcut: with the phone unlocked, it sent the SMS and reported success back to the app, and the app then showed "I've told ...". The JSON input (Get Dictionary from Input) has not been re-verified on a device. Not verified: that it can send with no taps on a locked phone (spike 003 is open). A tap may be needed.
- Not verified: Apple Foundation Models on a phone. The measured accuracy comes from a Mac (spike 001); whether it is available on the test phone was not checked (spike 005 is open). When it is unavailable or too slow, the keyword rules are used.
- Not verified: Taglish transcription accuracy across a full set of utterances (only 3 sentences were spoken in spike 004).
- Medical content is fixed JSON, written once and not generated. The guide screen shows: "This is a guide only. It does not replace a doctor or rescuer."
- Not built: spoken steps (text-to-speech), a quick trigger outside the app (Lock Screen control, Action Button), CPR mode, escalation after 30 and 60 seconds, shout or fall detection, the contact's reply side, Android, background listening. A Motion permission string exists but fall detection is not built.

## Repo map

- `Saklolo/` app source: `Services/` (transcription, classifier, alert, location), `Views/`, `Models/`, `Theme/`, `Resources/` (scripts, `keywords.json`, fonts)
- `SakloloTests/` unit tests
- `project.yml` XcodeGen project definition
- `docs/` PRD, project definition, spikes and findings; `DESIGN.md`, `PRODUCT.md` design and product notes
