# Saklolo — Product Requirements Document

**Summary.** Saklolo is an offline voice assistant for emergencies, built as an iPhone app for the AppBuildersPH Hackathon 2026 (theme: Local AI, solo entry). When someone calls "Tulong!", it understands the Taglish, texts and calls their contacts with a summary and GPS, and talks whoever is there through vetted first aid, one step at a time. Speech recognition, understanding, and guidance run on the phone, so it works with no data. Submission closes 10:00 AM, Oct 10, 2026.

What and why are defined in [PROJECT-DEFINITION.md](PROJECT-DEFINITION.md). This PRD turns them into testable requirements. Sources: [project brief](references/saklolo-project-brief.md) and the official [participant briefing](references/AppBuildersPH%20Hackathon%202026%20Participant%20Briefing.pdf).

## 1. Overview and objectives

- Alert the right people with a clear message and location, even with no data.
- Guide the person present through first aid until help arrives.
- Keep all AI on the device. Only SMS and calls use the cell network.
- Never let AI invent medical advice.
- Ship a working, demonstrable product by the deadline. Judging weights are in section 9.

## 2. Users and user stories

Primary users: families caring for older parents; elderly people living alone; families in flood/typhoon areas. Secondary users: the contacts who receive the alert (neighbors, barangay officials, family). Details in [PROJECT-DEFINITION.md](PROJECT-DEFINITION.md#problem).

- **US-1 (alone mode).** As an injured person who can't reach the phone, I want to say "Tulong, nadulas ako, di ako makatayo" so that my contacts are alerted and called without me touching anything.
- **US-2 (guide mode).** As a panicking family member, I want the phone to tell me what to do one step at a time so that I can help until rescuers arrive.
- **US-3 (alerted contact).** As a neighbor on the contact list, I want an SMS saying what happened, when, and where so that I can act at once.
- **US-4 (setup).** As a user, I want to enter my name and up to five contacts in priority order so that the right person is texted and called first.
- **US-5 (reviewer).** As a family member afterwards, I want to see what was said, what was sent, and whether it was delivered so that I know what happened.

## 3. Functional requirements

Tags: **Must** (core loop), **Wow** (right after the core loop), **Stretch** (only if ahead).

| ID | Tag | Requirement | Acceptance criteria |
| --- | --- | --- | --- |
| FR-1 | Must | Setup: user name and contacts with priority order | Can save a name and 1-5 contacts, each with name, phone, relation, priority. Order can be changed. Data persists after the app restarts. |
| FR-2 | Must | Big red "SAKLOLO" button on Home | Tapping it starts the flow from the check-in step. Works with Wi-Fi and cellular data off. |
| FR-3 | Wow | Voice trigger: "Tulong" / "Saklolo" while the app is open | With the app open on Home, saying "Tulong" starts the same flow as FR-2. The red button still works if voice fails. |
| FR-4 | Must | Spoken check-in | The phone says "Ano'ng nangyari?" through AVSpeechSynthesizer. Uses a Filipino voice if installed; otherwise the fallback (pre-recorded clips). |
| FR-5 | Must | On-device speech-to-text (WhisperKit) | Records up to 15s. A Taglish phrase is transcribed with no network. Live transcript shows on the Listening screen. |
| FR-6 | Must | On-device classification returning JSON | Output contains mode (alone/guide), situation, matching script, urgency, and a one-line summary. Mode follows the speaker ("nahulog ako" is alone; "nahulog si Papa" is guide). |
| FR-7 | Must | Keyword fallback | If the LLM fails or is slow, keyword matching still picks a script and summary, and the alert is sent anyway. The SMS is never blocked by the LLM. |
| FR-8 | Must | Offline GPS | Coordinates come from CoreLocation with no data. If a fix is unavailable, the last known location is used. |
| FR-9 | Must | Alert: SMS then call | SMS goes to all contacts in priority order with summary, time, and a maps link. Then contact #1 is called (`tel://`, one confirm tap). SMS is sent through a Shortcut with no tap. If silent send fails, fall back to the message composer (one tap). |
| FR-10 | Must | Guide mode | Speaks the matched script one step at a time. "okay" / "tapos na" advances; "ulitin" repeats. Big Next and Repeat buttons do the same. A banner shows who was texted. Reminds the user that help is on the way. |
| FR-11 | Must | Alone mode behavior | Alerts contacts, calls #1, and keeps talking to the person. If there is no reply, escalates after 30s ("Walang sagot pagkatapos bumagsak"). The escalation action itself is TBD (see section 11). |
| FR-12 | Must | Incident log and screen | Each incident stores trigger, mode, transcript, summary, script, location, start time, and per-contact SMS and call status. The Incident screen shows summary, contacts notified, and delivery status. |
| FR-13 | Wow | CPR mode | Within the unconscious script, speaks a count and plays a metronome beep. The pace value is TBD (to be taken from Red Cross material). |
| FR-14 | Stretch | Fall detection and silence escalation | CoreMotion detects a fall and starts the alone-mode flow. Needs Motion permission. |
| FR-15 | Stretch | Contact reply "PAPUNTA NA" | A reply from a contact is announced by the phone. |

### Safety requirements (all Must)

- **FR-S1.** The LLM only classifies. It never writes or edits medical instructions. Acceptance: every spoken step comes from a bundled JSON script, verified by reading the script files and the code path.
- **FR-S2.** Scripts are fixed JSON based on Philippine Red Cross basic first aid. MVP set (max 4): fall/can't move, heavy bleeding, unconscious, head injury. Acceptance: each script has been checked against Red Cross material before submission.
- **FR-S3.** If nothing matches, the general script runs (stay calm, check breathing, don't move them, help is coming).
- **FR-S4.** Every script starts by making sure help is being called. Acceptance: the first step of each script says so.
- **FR-S5.** The app shows the source (Philippine Red Cross) and the disclaimer "Gabay lang ito. Hindi ito kapalit ng doktor o rescuer."
- **FR-S6.** The alert is always sent, regardless of classification result or mode.

## 4. Non-functional requirements

- **Offline operation.** With Wi-Fi and cellular data off, the full flow works except delivery of SMS and calls, which use the cell network only. No AI call goes to a cloud API.
- **Latency.** The alert must not wait on the LLM (FR-7). Numeric targets for response time are TBD; none are given in the sources. The only limits given are 15s recording and 30s escalation.
- **Privacy.** No audio leaves the device. No per-use cost.
- **Permissions.** Microphone, Location (When In Use), Motion (only if FR-14 is built).
- **Language.** Taglish input and Filipino speech output. Bisaya/Ilocano are out of scope.
- **Reliability.** Each AI layer has a fallback (see section 8). Reliability targets are TBD.
- **Platform.** iOS, SwiftUI. Apple Foundation Models needs an Apple Intelligence iPhone (15 Pro or newer).

## 5. Screens and key flows

Screens: Setup, Home (red button, "Nakikinig" status), Listening (live transcript), Guide (one big step, Next/Repeat, "Na-text na sina Kuya at Tita" banner), Incident.

Main flow: trigger, check-in, listen (up to 15s), understand, alert (SMS then call), guide (guide mode), log. Full step list in [PROJECT-DEFINITION.md](PROJECT-DEFINITION.md#what-saklolo-does).

## 6. Data model

- Contact: id, name, phone, relation, priority
- Script: id, title, keywords, steps[] (bundled JSON)
- Incident: id, trigger, mode, transcript, summary, script_id, lat, lng, started_at
- Alert: id, incident_id, contact_id, sms_sent_at, called

Storage: SwiftData (fallback UserDefaults).

## 7. Out of scope

- Android, smartwatch, background listening with the app closed.
- More scripts (burns, choking, stroke signs, seizures); Bisaya/Ilocano.
- Barangay responder mode, family dashboard.
- Live deployment (repo instructions for judges are enough).

## 8. Dependencies, assumptions, risks

**Dependencies:** a Mac with Xcode and an Apple ID; an iPhone with a SIM; WhisperKit; Apple Foundation Models (or Gemma/Qwen via MLX Swift or llama.cpp); the Shortcuts app.

**Assumptions (unverified):** Apple's on-device model runs on the target iPhone; the Shortcut sends SMS silently; a Filipino TTS voice is installed.

**Risks**

| Risk | Fallback |
| --- | --- |
| No Mac / Xcode | Blocker for iOS. Borrow a Mac or switch to Android |
| iPhone can't run Apple's on-device model | Gemma/Qwen via MLX Swift; else keyword rules (disclose honestly) |
| Shortcut silent send fails | MFMessageComposeViewController with one tap |
| Whisper slow or weak on Taglish | Smaller model; keyword fallback; big red button |
| Medical advice concerns | Fixed vetted scripts, LLM only classifies, source shown, disclaimer, always calls for help |
| No signal at the venue | Test SMS during AV check; backup video |

**Competition rules that bind the build** (participant briefing): substantially built during the hackathon; a meaningful part of AI inference runs locally; all models, frameworks, APIs, existing code and assets, and AI dev tools disclosed; only listed participants compete; no external help; one submission, no edits; public repo by the deadline. Full list in [PROJECT-DEFINITION.md](PROJECT-DEFINITION.md#constraints--assumptions).

## 9. Success metrics

**Judging criteria** (participant briefing):

| Criterion | Weight |
| --- | --- |
| Problem & Usefulness | 25% |
| Local AI Implementation | 25% |
| Technical Execution | 20% |
| Innovation | 15% |
| Product & Demo Quality | 15% |

Prioritize a working product over slides. Fake benchmarks can get results disputed, so report only real numbers.

**Demo-ready checks**

- With Wi-Fi and cellular data off, on a real iPhone with a real SIM and contact: the red button sends the SMS with summary and GPS, calls contact #1, and starts guidance.
- The keyword fallback sends the SMS when the LLM is forced to fail.
- Each shipped script is checked against Red Cross material, shows its source, and carries the disclaimer.
- The red button works if voice fails; a backup video exists if everything fails.
- The repo builds from a fresh clone using the README.
- The submission states what runs locally (speech-to-text, classification, guidance, GPS), what needs internet (nothing; SMS and calls use the cell network), and why local AI helps.

## 10. Milestones

Coarse, from the brief's build timeline (exact hours stay in the brief). Build starts 2:30 PM Oct 9 per the briefing.

1. **Foundation.** Xcode project on the iPhone; contacts screen.
2. **Alert loop.** Red button to Shortcut SMS, call, and GPS working end to end.
3. **Guidance.** Scripts JSON and Guide screen with TTS and Next/Repeat.
4. **Understanding.** WhisperKit transcript to keyword match; then on-device LLM classification with fallback.
5. **Wow and polish.** Voice trigger, CPR metronome, UI polish.
6. **Full test** with a real SIM and contact. **Feature freeze 8:00 AM Oct 10.**
7. **Wrap-up.** Demo video, README, disclosures, script check against Red Cross material; make the repo public; post; submit once.
8. **Deadline: 10:00 AM, Oct 10, 2026.** No extensions.

Demo Day (Oct 10, Cyberzone SM Makati) logistics are in the brief.

## 11. Open questions

Carried over unchanged from the brief:

- Do you have a Mac with Xcode?
- Which iPhone model (decides Apple's on-device model vs MLX)?
- Who is the emergency contact at the demo?
- GitHub repo link for the last slide

Gaps noted while writing this PRD (not in the sources, so left as TBD):

- What alone mode does when the 30s escalation fires, beyond the quoted message.
- The metronome pace for CPR mode.
- Numeric latency and reliability targets.
