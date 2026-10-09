# Saklolo — User Flows

This walks through Saklolo from the user's side: what they say, see, and hear, and what the phone does. It covers setup, the two emergency modes, fallbacks, the contact's view, the incident record, and the demo.

What and why: [PROJECT-DEFINITION.md](PROJECT-DEFINITION.md). Requirements (FR-x IDs): [PRD.md](PRD.md). Source: [project brief](references/saklolo-project-brief.md).

Anything the sources don't specify is marked **TBD**.

## Main emergency flow

```mermaid
flowchart TD
    A[Trigger: "Tulong" / "Saklolo" heard, or big red button] --> B["Phone speaks: Ano'ng nangyari?"]
    B --> C[Listen: record up to 15s]
    C --> D[Whisper transcribes Taglish]
    D -->|weak or failed| D2[Keyword matching on what was heard, or red button path]
    D --> E{Local LLM classifies}
    D2 --> E2[Keyword fallback picks script and summary]
    E -->|JSON: mode, situation, script, urgency, summary| F{Mode?}
    E -->|fails or slow| E2
    E2 --> F
    F -->|alone: nahulog ako| G[Alert always: SMS to contacts in priority order, then call #1]
    F -->|guide: nahulog si Papa| G
    G -->|silent Shortcut send fails| G2[Message composer, one tap to send]
    G --> H{Mode branch}
    G2 --> H
    H -->|alone| I[Keep talking to the injured person]
    I -->|no reply for 30s| J[Escalate: Walang sagot pagkatapos bumagsak; next action TBD]
    H -->|guide| K{Script matched?}
    K -->|yes| L[Speak script one step at a time]
    K -->|no| M[General script: stay calm, check breathing, don't move them, help is coming]
    L --> N[okay / tapos na = next, ulitin = repeat, or Next/Repeat buttons]
    M --> N
    N --> O[Reminder: help is on the way]
    I --> P[Log incident]
    J --> P
    O --> P
    P --> Q[Incident screen: transcript, summary, delivery status]
```

## 1. First-time setup

The user sets the app up once, ahead of time, when nothing is wrong.

1. Open the app. The **Setup** screen asks for the user's name.
2. Add 1 to 5 contacts. For each: name, phone, relation.
3. Put the contacts in priority order. Contact #1 gets the phone call, so order matters.
4. The phone asks for permissions: **Microphone** and **Location (When In Use)**. Motion is requested only if fall detection is built.
5. Setup is saved and the user lands on **Home**.

Gaps: whether setup is revisited later to edit contacts, and when the permission prompts appear (at first launch or at first use), are **TBD**.

## 2. Alone mode

The injured person can't reach the phone or can't get up.

1. **Say:** "Tulong, nadulas ako, di ako makatayo." (Home is showing "Nakikinig".)
2. **Hear:** the phone asks "Ano'ng nangyari?"
3. **Say** what happened. The phone listens for up to 15s. The **Listening** screen shows the live transcript.
4. **Phone:** Whisper transcribes the Taglish on the device. The local LLM returns JSON (mode, situation, script, urgency, one-line summary). "Nahulog **ako**" makes it alone mode.
5. **Phone, always:** it texts every contact in priority order with the summary and GPS, then calls contact #1. The call needs one confirm tap, which may be hard for an injured person (how this is handled is **TBD**).
6. **Hear:** the phone keeps talking to the injured person. What it says in this mode beyond that is **TBD** in the sources.
7. **No reply for 30s:** the phone escalates with "Walang sagot pagkatapos bumagsak". What the escalation does next is **TBD**.

## 3. Guide mode

A companion (spouse, child, neighbor) is there.

1. **Say:** "Tulong! Nahulog si Papa, dumudugo ang ulo!" The same check-in and listen steps run as in alone mode (steps 2-4 above). "Si Papa" makes it guide mode.
2. **Phone, in the background:** the alert goes out as in alone mode: SMS to all contacts, then call #1.
3. **See:** the **Guide** screen shows one big step at a time, with Next and Repeat buttons and a banner such as "Na-text na sina Kuya at Tita".
4. **Hear:** the phone speaks the matched script. Every script starts by making sure help is being called.
5. **Move on:** the companion says "okay" or "tapos na" (or taps Next) to hear the next step. They say "ulitin" (or tap Repeat) to hear it again.
6. **Reminders:** the phone reminds the companion that help is on the way. How often is **TBD**.
7. **CPR mode (Wow tier):** in the unconscious script, if the person isn't breathing, the phone starts a spoken count with a metronome beep. The pace is **TBD**.
8. **See:** the app shows the Philippine Red Cross source and the disclaimer "Gabay lang ito. Hindi ito kapalit ng doktor o rescuer." Where on screen they appear is **TBD**.

The four MVP scripts: fall/can't move, heavy bleeding, unconscious, head injury. The LLM only picks which script; it never writes the steps.

## 4. Fallback paths

- **Voice doesn't work:** press the big red SAKLOLO button on Home. It starts the same flow. (The "Tulong" voice trigger is a Wow-tier feature that works only while the app is open.)
- **Speech-to-text is weak or slow:** the app can use a smaller Whisper model. Keyword matching and the red button remain available.
- **LLM fails or is slow:** keyword matching picks the script and summary. The SMS is never held up by the LLM.
- **No script matches:** the general script runs: stay calm, check breathing, don't move them, help is coming.
- **Silent SMS send fails:** the message composer opens and the user taps once to send.
- **No GPS fix:** the last known location is used.
- **No Filipino voice installed:** pre-recorded clips are the fallback.

The alert is sent in every one of these cases.

## 5. The contact's view

The contact is a neighbor, barangay official, or family member.

1. **Receive an SMS**, for example:
   > SAKLOLO: Si Papa nahulog, dumudugo ang ulo, gising pa. 7:42pm. Lokasyon: maps.apple.com/?ll=14.6507,121.0494
2. **Tap** the maps link to see the location.
3. **Receive a call** if they are contact #1. Other contacts get the SMS only.
4. **Stretch tier:** reply "PAPUNTA NA" and the user's phone announces it.

## 6. After the incident

The **Incident** screen shows:

- the transcript of what was said,
- the one-line summary,
- the contacts notified, with delivery status.

Each incident is saved with the script used, the location, and the start time. How the user reaches the Incident screen (automatically after the flow, or from Home) is **TBD**.

## 7. Demo-day flow

Short version. Logistics live in the brief.

1. Mirror the iPhone to the projector. Turn Wi-Fi and cellular data off on screen; keep cellular on for SMS.
2. Use a pillow as "Papa" and a towel as the cloth.
3. An organizer or audience member, saved as the emergency contact, reads the SMS aloud when it arrives.
4. Run alone mode or guide mode live (about 2 minutes of the 5-minute pitch).
5. If voice fails, press the big red button. If everything fails, play the backup video.

## Screen navigation

- **Setup** to **Home**: after saving name and contacts.
- **Home** to **Listening**: red button, or "Tulong" / "Saklolo" heard.
- **Listening** to **Guide**: when guide mode is chosen.
- **Listening** to ?: alone mode has no dedicated screen in the sources (**TBD**).
- **Guide** or alone flow to **Incident**: when the incident ends. The exact trigger is **TBD**.
- **Incident** to **Home**: return path **TBD**.
