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
| FR-3 | Wow, cut for now | Voice trigger: "Tulong" / "Saklolo" while the app is open | Not in the current design: it needs an always-open microphone on Home and is not built. The red button (FR-2) and the quick triggers (FR-T2, FR-T3) start the flow instead. |
| FR-4 | Must | Spoken check-in | The phone says "Ano'ng nangyari?" through AVSpeechSynthesizer. Uses the built-in English voice. The text is always on screen, so no recorded clips are needed. |
| FR-5 | Must | On-device speech-to-text (WhisperKit) | Records up to 15s. A Taglish phrase is transcribed with no network. Live transcript shows on the Listening screen. |
| FR-6 | Must | On-device classification returning JSON | Output contains mode (alone/guide), situation, matching script, urgency, and a one-line summary. Mode follows the speaker ("nahulog ako" is alone; "nahulog si Papa" is guide). |
| FR-7 | Must | Keyword fallback | If the LLM fails or is slow, keyword matching still picks a script and summary, and the alert is sent anyway. The SMS is never blocked by the LLM. |
| FR-8 | Must | Offline GPS | Coordinates come from CoreLocation with no data. If a fix is unavailable, the last known location is used. |
| FR-9 | Must | Alert: SMS then call | One SMS goes to all contacts in priority order with summary, time, and a maps link. It is sent when understanding finishes, and no later than 10 s after the trigger; if nothing was understood by 10 s, a general SMS ("Maria needs help" with the maps link) goes out instead. Then contact #1 is called (`tel://`, one confirm tap). SMS is sent through a Shortcut with no tap. If silent send fails, fall back to the message composer (one tap). |
| FR-10 | Must | Guide mode | Speaks the matched script one step at a time. "okay" / "tapos na" advances; "ulitin" repeats. Big Next and Repeat buttons do the same. A banner shows who was texted. Reminds the user that help is on the way. |
| FR-11 | Must | Alone mode behavior | Sends nothing at understanding. A countdown (10 s, TBD) to "I need help" runs in the chat; when it ends, or the person taps it, the alert goes out (SMS, then call #1) and the phone keeps talking to the person. A slide "I'm okay" before then cancels it and nothing is sent. If there is no reply, escalates after 30s ("Walang sagot pagkatapos bumagsak"). The escalation action itself is TBD (see section 11). |
| FR-12 | Must | Incident log and screen | Each incident stores trigger, mode, transcript, summary, script, location, start time, a short timeline, and per-contact SMS and call status. An incident log lists past incidents, newest first (from the Home menu); a detail screen shows summary, timeline, contacts notified and delivery status, with Share summary and Delete. Stored on the phone only; no audio is kept. After a session ends the app opens that incident's detail. |
| FR-13 | Wow | CPR mode | Within the unconscious script, speaks a count and plays a metronome beep. The pace value is TBD (to be taken from Red Cross material). |
| FR-14 | Stretch | Fall detection and silence escalation (trigger T6) | CoreMotion detects a fall and enters the alone-mode check-in (FR-B2). Needs Motion permission. Runs only while the app is running. |
| FR-15 | Stretch | Contact reply "PAPUNTA NA" | A reply from a contact is announced by the phone. |

### Safety requirements (all Must)

- **FR-S1.** The LLM only classifies. It never writes or edits medical instructions. Acceptance: every spoken step comes from a bundled JSON script, verified by reading the script files and the code path.
- **FR-S2.** Scripts are fixed JSON based on Philippine Red Cross basic first aid. MVP set (max 4): fall/can't move, heavy bleeding, unconscious, head injury. Acceptance: each script has been checked against Red Cross material before submission.
- **FR-S3.** If nothing matches, the general script runs (stay calm, check breathing, don't move them, help is coming).
- **FR-S4.** Every script starts by making sure help is being called. Acceptance: the first step of each script says so.
- **FR-S5.** The app shows the source (Philippine Red Cross) and the disclaimer "Gabay lang ito. Hindi ito kapalit ng doktor o rescuer."
- **FR-S6.** The alert is always sent, regardless of classification result or mode.

### Triggers

Items marked **proposed** are not in the original brief. They keep the brief's tiers (Must/Wow/Stretch). T1, T4 and T6 already exist as FR-2, FR-3 and FR-14.

| ID | Tag | Trigger | Acceptance criteria |
| --- | --- | --- | --- |
| FR-T1 | Must (= FR-2) | Big red button in the app | Starts the flow immediately. No countdown. |
| FR-T2 | Must-light, proposed | Quick trigger outside the app: the Saklolo control on the Lock Screen or in Control Center (iOS 18+), or on the Action Button (iPhone 15 Pro+) | The control opens Saklolo straight into Listening (after Face ID or the passcode). Nothing is announced before the phone understands. The app then sends the alert through the Saklolo Shortcut and the chat continues to guide mode. Whether the Shortcut sends without extra taps is unverified (spike 003, see section 8). |
| FR-T3 | Proposed | Home Screen widget with a big red SAKLOLO button | Phone must be unlocked. Tapping it opens Saklolo straight into Listening, with the same ✕ Cancel (FR-B1). |
| FR-T4 | Wow (= FR-3), cut for now | Voice "Tulong" / "Saklolo" while the app is open | Not in the current design (see FR-3). |
| FR-T5 | Stretch, proposed | Shout/scream detection using Apple's on-device sound classification | Passive trigger. It would enter the alone-mode check-in (FR-B2). The class list must be verified in Apple's docs before relying on it. |
| FR-T6 | Stretch (= FR-14) | Fall detection with CoreMotion | Passive trigger, alone-mode check-in. This is the builder's own version (Apple's fall detection is Watch-based) and runs only while the app is running. |

**Alert and guidance.** A quick trigger opens the app straight into Listening, so everything runs from the foreground: the alert (location, SMS to all contacts, call #1, sent through the Saklolo Shortcut), then guide mode. The alert does not depend on the AI.

**Supporting behaviours (all proposed)**

| ID | Requirement | Acceptance criteria |
| --- | --- | --- |
| FR-B1 | Cancel a mistaken start, every start | A quiet "✕ Cancel" in the header of Listening. Nothing is sent before understanding finishes, so cancelling in that time sends nothing. There is no alert banner or countdown. |
| FR-B2 | Passive triggers (T5, T6) enter the alone-mode check-in | A fall or shout starts the alone check-in with a first line such as "I think you fell. Are you okay?". The countdown to "I need help" and the "I'm okay" slide already there replace a separate confirm step. Stretch. |
| FR-B3 | False alarm message | If the user says it was a false alarm after an alert went out (from the Guide sheet menu, or "I'm okay" in alone mode), a "False alarm" SMS goes to the same contacts, with wording that fits the mode. Wording TBD. |
| FR-B4 | Queued SMS | With no cell signal, the SMS is queued and retried when signal returns. The incident shows it as "queued". Status wording TBD. |
| FR-B5 | Low-confidence classification | If the classifier is not confident, run the general script and ask one spoken question. The safety rules still hold: the LLM only classifies and every script starts with help being called. The confidence threshold is TBD. |

**Alert timing.** There is one SMS per incident, so nothing is sent at the tap. It goes out when understanding finishes (no later than 10 s after the trigger), or as a general SMS at 10 s. Nothing about alerting is shown before that, so the user is not alarmed. **Open:** whether to send an update SMS with the summary when the 10 s limit was hit first.

## 4. Non-functional requirements

- **Offline operation.** With Wi-Fi and cellular data off, the full flow works except delivery of SMS and calls, which use the cell network only. No AI call goes to a cloud API.
- **Latency.** The alert must not wait on the LLM (FR-7). Numeric targets for response time are TBD; none are given in the sources. The only limits given are 15s recording and 30s escalation.
- **Privacy.** No audio leaves the device. No per-use cost.
- **Permissions.** Microphone, Location (When In Use), Motion (only if FR-14 is built).
- **Offline wording.** SMS and calls still need cell signal. Say "no data needed", not "no network needed".
- **Language.** Taglish input and Filipino speech output. Bisaya/Ilocano are out of scope.
- **Reliability.** Each AI layer has a fallback (see section 8). Reliability targets are TBD.
- **Platform.** iOS, SwiftUI. Apple Foundation Models needs iOS 26 on Apple Intelligence hardware (iPhone 15 Pro or newer). The Lock Screen control (T2) needs iOS 18+; the Action Button needs iPhone 15 Pro+.

## 5. Screens and key flows

Screens: Setup, Home (red button, "Nakikinig" status), Listening (live transcript), Guide (one big step, Next/Repeat, "Na-text na sina Kuya at Tita" banner), Incident.

Main flow: trigger, check-in, listen (up to 15s), understand, alert (SMS then call), guide (guide mode), log. Full step list in [PROJECT-DEFINITION.md](PROJECT-DEFINITION.md#what-saklolo-does). Trigger variants, countdown, and confirm step are in [USER-FLOW.md](USER-FLOW.md#ways-to-trigger).

## 6. Data model

- Contact: id, name, phone, relation, priority
- Script: id, title, keywords, steps[] (bundled JSON)
- Incident: id, trigger, mode, transcript, summary, script_id, lat, lng, started_at
- Alert: id, incident_id, contact_id, sms_sent_at, called

Storage: SwiftData (fallback UserDefaults).

## 7. Out of scope

- Android, smartwatch, background listening with the app closed. True always-on listening stays cut: it needs a background audio session, drains the battery, and shows the orange mic dot.
- A loud-commotion / sound-spike trigger: roadmap only, because it would cause too many false alarms.
- Contacting 911. An optional "call 911" second tap is TBD / roadmap. Nothing in the MVP contacts 911.
- More scripts (burns, choking, stroke signs, seizures); Bisaya/Ilocano.
- Barangay responder mode, family dashboard.
- Live deployment (repo instructions for judges are enough).

## 8. Dependencies, assumptions, risks

**Dependencies:** a Mac with Xcode and an Apple ID; an iPhone with a SIM; WhisperKit; Apple Foundation Models (or Gemma/Qwen via MLX Swift or llama.cpp); the Shortcuts app.

**Assumptions (unverified):** Apple's on-device model runs on the target iPhone (demo phone: iPhone 15 Pro Max, which needs iOS 26+ and Apple Intelligence turned on and fully downloaded; verify before the demo); the Shortcut sends SMS silently; a Filipino TTS voice is installed. Also unverified: whether the Shortcut can send SMS and place a call on a locked phone. Test it with a real SIM.

**Risks**

| Risk | Fallback |
| --- | --- |
| No Mac / Xcode | Blocker for iOS. Borrow a Mac or switch to Android |
| iPhone can't run Apple's on-device model | Gemma/Qwen via MLX Swift; else keyword rules (disclose honestly) |
| Apple's model is wrong or blocked on an emergency phrase. Spike 001 (Mac): 35/36 script and mode with the keyword merge, but the safety guardrail blocks some injured-child phrasings and the model sometimes misreads script or mode | Keyword classifier runs first and replaces the LLM result on any error, timeout, or a "general" answer when keywords match. The LLM never delays or blocks the SMS and call. Disclose that the AI can be wrong |
| Phone latency is unmeasured (0.75s median on a Mac) | 3s timeout then keyword result; test on the iPhone 15 Pro Max |
| MLX 3B models (spike 002) were too inaccurate on Taglish (3 to 6 of 12 script, tested without examples) | Not used for the demo. Revisit after tuning or fine-tuning |
| Shortcut silent send fails | MFMessageComposeViewController with one tap |
| Whisper slow or weak on Taglish | Smaller model; keyword fallback; big red button |
| Medical advice concerns | Fixed vetted scripts, LLM only classifies, source shown, disclaimer, always calls for help |
| No signal at the venue | Test SMS during AV check; backup video |
| Shortcut may not send SMS and call on a locked phone (unverified, proposed triggers) | Test with a real SIM; if it fails, T2 needs an unlock, or the red button inside the app is the path |
| Alone mode only works if the phone is within earshot of the voice | State this limit honestly; quick triggers (T2) cover the case where the phone is reachable but the user can't talk |
| Widget (T3) cannot use the mic and needs an unlocked phone | It only opens the app; the app handles listening |
| OS and hardware gates: Lock Screen control needs iOS 18; Apple's on-device model needs iOS 26 and iPhone 15 Pro or newer | Gemma/Qwen via MLX Swift; else keyword rules. Other triggers still work |
| The call (`tel://`) still needs one confirm tap | Accepted limit; SMS goes out first |
| Passive triggers (T5, T6) cause false alarms | Confirm step (10s), cancel path, "False alarm" SMS; a sound-spike trigger is excluded for this reason |
| Sound classification class list unverified (T5) | Verify in Apple docs before building; drop T5 if no suitable class exists |
| Pitch overclaims ("calls help", "no network needed") | Say "alerts your circle" and "no data needed". Nothing here contacts 911 |

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
5. **Triggers and polish, in this order.** Red button (done at step 2); voice while the app is open; quick trigger via Shortcut / Action Button / widget (proposed); shout detection (proposed Stretch); fall detection with confirm (Stretch). Also CPR metronome and UI polish. Anything unfinished at the freeze is cut.
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

Added (proposed triggers):

- Does the Shortcut send SMS and call on a locked phone?
- Which iPhone/iOS version?

Gaps noted while writing this PRD (not in the sources, so left as TBD):

- Whether to send an update SMS when the 10 s limit was hit before understanding finished.
- Wording of the "False alarm" SMS and the queued status; confidence threshold for FR-B5.
- How the 10s confirm window relates to the 30s alone-mode silence escalation.

- What alone mode does when the 30s escalation fires, beyond the quoted message.
- The metronome pace for CPR mode.
- Numeric latency and reliability targets.
