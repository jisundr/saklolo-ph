# Saklolo — Project Definition

**Summary.** Saklolo is an offline voice assistant for emergencies, built as an iPhone app for the AppBuildersPH Hackathon 2026 (theme: Local AI, solo entry). When someone shouts "Tulong!", it understands the Taglish, texts and calls their contacts with a summary and GPS, and talks whoever is there through first aid, one step at a time, until help arrives. The AI runs on the phone, so it works with no data. Submission closes **10:00 AM, Oct 10, 2026**.

Sources: [project brief](references/saklolo-project-brief.md) and the official [participant briefing (PDF)](references/AppBuildersPH%20Hackathon%202026%20Participant%20Briefing.pdf). The brief also holds the build timeline, pitch script, demo setup, submission checklist, and demo-day logistics. They are not repeated here.

## Problem

A parent has an accident. The phone is out of reach. The family member who is there panics and doesn't know first aid. Another family member happens to know what to do, and that is the only reason it ends well. What if that person isn't there, or you're alone?

Two things go wrong in an accident:

1. The phone is out of reach, or there is no data, so no one is alerted.
2. The person present panics, doesn't know first aid, and has no time to search online.

Apple/Google fall detection, Emergency SOS, and Life360 need a wearable, a button press, or internet, and they only send an alert. None tell the person in the room what to do. Apple Emergency SOS calls 911 and shares location, but it doesn't understand Taglish, say what happened, alert the neighbor first, or guide the family.

**Who it's for**

- Families caring for older parents (primary). They need calm, step-by-step guidance and others alerted.
- Elderly people living alone. They need help without reaching the phone, with a neighbor alerted first.
- Families in flood or typhoon areas. They have no data and need a message rescuers can act on.
- Secondary users are the contacts who get the alert: neighbors, barangay officials, family.

**Why local AI.** Emergencies happen where there's no data: weak signal at home, typhoons, provinces, prepaid load with no data promo. Speech recognition, understanding, and first-aid guidance must work instantly and offline. Only SMS and calls use the cell network. No home audio goes to a server, and it costs nothing per use.

## What Saklolo does

**Core flow**

1. Trigger: "Tulong" / "Saklolo" heard, or the big red button. (Proposed extra triggers are listed under Goals.)
2. Check-in: the phone asks "Ano'ng nangyari?" and listens for up to 15s.
3. Understand: Whisper transcribes the Taglish. A local LLM returns JSON (mode, situation, matching script, urgency, one-line summary).
4. Alert, always: SMS to contacts in priority order with summary and GPS, then call contact #1.
5. Guide: speak the matched first-aid script one step at a time. The companion says "okay" / "tapos na" to continue or "ulitin" to repeat.
6. Log: save the incident with transcript, script used, and delivery status.

Example SMS: `SAKLOLO: Si Papa nahulog, dumudugo ang ulo, gising pa. 7:42pm. Lokasyon: maps.apple.com/?ll=14.6507,121.0494`

**Two modes.** The AI picks one from what it hears ("nahulog **ako**" vs "nahulog **si Papa**").

- **Alone mode:** the injured person is speaking. Saklolo alerts contacts, calls #1, and keeps talking to them. With no reply after 30s, it escalates ("Walang sagot pagkatapos bumagsak").
- **Guide mode:** a companion is speaking. Saklolo alerts contacts in the background and talks the companion through first aid.

**Safety rule.** The LLM never writes medical instructions. It only classifies. Steps come from fixed scripts based on Philippine Red Cross basic first aid, stored as JSON. Every script starts by making sure help is being called. If nothing matches, a general script runs (stay calm, check breathing, don't move them, help is coming).

MVP scripts (max 4): fall and can't move; heavy bleeding; unconscious (with CPR count); head injury.

**Screens:** Setup, Home (big red button), Listening (live transcript), Guide (one big step, Next/Repeat, "Na-text na sina Kuya at Tita" banner), Incident.

## Goals

**Must have (core loop)**
- Setup: user name, 1-5 contacts with priority order.
- Big red "SAKLOLO" button (demo safety net).
- Spoken check-in prompt (AVSpeechSynthesizer).
- On-device speech-to-text (WhisperKit).
- On-device LLM classification with JSON output.
- Keyword fallback if the LLM fails or is slow. The SMS is never blocked.
- Offline GPS (CoreLocation).
- SMS to all contacts via a Shortcut, then call contact #1.
- Guide mode: step-by-step script, voice "okay/ulitin" plus big Next/Repeat buttons.
- Incident screen: transcript, summary, delivery status.

**Wow (right after the core loop)**
- Voice trigger "Tulong" while the app is open.
- CPR mode: spoken count and metronome beep at the right pace.

**Stretch (only if ahead)**
- Fall detection (CoreMotion) with silence escalation.
- Contacts reply "PAPUNTA NA" and the phone announces it.

**Triggers** (proposed additions beyond the brief; details in [PRD.md](PRD.md#triggers))
- Existing: big red button (Must), voice "Tulong" / "Saklolo" while the app is open (Wow), fall detection (Stretch).
- Proposed: a quick trigger outside the app (Lock Screen control, Action Button, Back Tap, or "Hey Siri, Saklolo") that runs the Saklolo Shortcut, with a 5-second cancel countdown; a Home Screen widget with a red button; shout detection (Stretch).
- Passive triggers (shout, fall) ask "Okay ka lang?" for 10s before sending.

**Before submission**
- Check every script against Philippine Red Cross first-aid material, show the source in the app, and show the disclaimer "Gabay lang ito. Hindi ito kapalit ng doktor o rescuer."

## Non-goals

Cut from the MVP and pitched as the roadmap:
- Android, smartwatch, background listening with the app closed. True always-on listening needs a background audio session, drains the battery, and shows the orange mic dot.
- A loud-commotion / sound-spike trigger: too many false alarms.
- Contacting 911. An optional "call 911" second tap is TBD / roadmap.
- More scripts (burns, choking, stroke signs, seizures); Bisaya/Ilocano.
- Barangay responder mode, family dashboard.

Deploying is not required for submission.

## Stakeholders

- The builder: solo entry, builds and presents.
- Primary and secondary users, as above.
- Hackathon judges and organizers, who review the repo as of the deadline and may question medical advice.

## Constraints & assumptions

- **Deadline:** 10:00 AM, Oct 10, 2026. No extensions, one submission only, code freezes at 10:00, repo public before then.
- **Offline AI:** nothing for the AI may need internet. Only SMS and calls use the cell network.
- **Official rules (participant briefing):**
  - Substantially built during the hackathon. Build starts 2:30 PM Oct 9, remote, overnight.
  - A meaningful part of AI inference runs locally. Core Local AI cannot depend entirely on a cloud AI API; cloud APIs are allowed only as secondary components.
  - Disclose all models, frameworks, APIs and cloud services, existing code and assets, and AI dev tools.
  - Only participants listed on appbuildersph.com/hackathon may compete. External help from outside the hackathon means disqualification.
  - Deploying is not required if the repo has instructions for judges.
  - Finalists (10-15) are announced 1:00 PM Oct 10 and must pitch in person: 5 min plus 3 min Q&A.
- **Tooling:** needs a Mac with Xcode and an Apple ID to install on the iPhone. Permissions: Microphone, Location (When In Use), Motion (only if fall detection is built).
- **Unverified assumptions:** Apple Foundation Models runs on the target iPhone (needs iOS 26 and Apple Intelligence hardware, 15 Pro or newer), and the Shortcut can send SMS silently. Both have fallbacks below.
- **Honest limits (proposed triggers):**
  - Alone mode works only if the phone is within earshot of the voice.
  - Whether the Shortcut can send SMS and place a call on a locked phone is unverified. Test with a real SIM.
  - The widget cannot use the mic and needs an unlocked phone. The Lock Screen control needs iOS 18+.
  - The call (`tel://`) still needs one confirm tap.
  - Nothing here contacts 911.
- **Pitch wording:** say "alerts your circle", not "calls help"; say "no data needed", not "no network needed".

**Stack (iOS)**

| Layer | Choice | Fallback |
| --- | --- | --- |
| App | SwiftUI, Xcode | none |
| Speech-to-text | WhisperKit | Smaller Whisper model; big red button |
| Understanding | Apple Foundation Models | Gemma/Qwen via MLX Swift or llama.cpp; then keyword rules |
| First-aid content | Bundled JSON scripts | none |
| TTS | AVSpeechSynthesizer (Filipino voice if installed) | Pre-recorded clips |
| Location | CoreLocation | Last known location |
| SMS | Shortcut via `shortcuts://run-shortcut?name=Saklolo&input=text` ("Show When Run" off sends without a tap) | MFMessageComposeViewController (one tap) |
| Call | `tel://` (one confirm tap) | none |
| Storage | SwiftData | UserDefaults |

**Data model**
- Contact: id, name, phone, relation, priority
- Script: id, title, keywords, steps[] (bundled JSON)
- Incident: id, trigger, mode, transcript, summary, script_id, lat, lng, started_at
- Alert: id, incident_id, contact_id, sms_sent_at, called

**Risks**

| Risk | Fallback |
| --- | --- |
| No Mac / Xcode | Blocker for iOS. Borrow a Mac or switch to Android |
| iPhone can't run Apple's on-device model | Gemma/Qwen via MLX Swift; else keyword rules (disclose honestly) |
| Shortcut silent send fails | MFMessageComposeViewController with one tap |
| Medical advice concerns | Fixed vetted scripts, LLM only classifies, source shown, disclaimer, always calls for help |
| Whisper slow or weak on Taglish | Smaller model; keyword fallback; big red button |
| No signal at the venue | Test SMS during AV check; backup video |

## Open questions

Carried over as-is from the brief:

- Do you have a Mac with Xcode?
- Which iPhone model (decides Apple's on-device model vs MLX)?
- Who is the emergency contact at the demo?
- GitHub repo link for the last slide

Added (proposed triggers):

- Does the Shortcut send SMS and call on a locked phone?
- Which iPhone/iOS version?

## Success criteria

- With Wi-Fi and cellular data off, on a real iPhone with a real SIM and contact, the red button (and voice) sends the SMS with summary and GPS, calls contact #1, and guides first aid.
- If the LLM fails or is slow, the keyword fallback still sends the SMS.
- Every shipped script is checked against Philippine Red Cross material, shows its source, and carries the disclaimer.
- Submitted once, before 10:00 AM, Oct 10, 2026, with a public repo that builds from a fresh clone using the README.
- The submission can state that nothing requires internet and explain why the product benefits from local AI.

### How it will be judged

From the participant briefing. Half the score is usefulness and how real the Local AI is.

| Criterion | Weight | Question |
| --- | --- | --- |
| Problem & Usefulness | 25% | Does it solve a genuine problem for a clear target user? |
| Local AI Implementation | 25% | Is local inference fundamental, and does it give a meaningful advantage? |
| Technical Execution | 20% | Does it actually work, reliably enough for a live demonstration? |
| Innovation | 15% | Is it meaningfully different? Does Local AI enable something new? |
| Product & Demo Quality | 15% | Is the UX usable, and is the live demonstration convincing? |

- Prioritize a working product over a large number of slides.
- Fake benchmarks (like a pre-existing project or outside help) can get results disputed. Report only real numbers.
