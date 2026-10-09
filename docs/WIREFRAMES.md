# Saklolo — Wireframes

Low-fidelity wireframes for every screen and state in [USER-FLOW.md](USER-FLOW.md): 25 phones in seven groups, including proposed quick triggers and confirmations. Requirements are in [PRD.md](PRD.md); the screen list comes from the [project brief](references/saklolo-project-brief.md). Names, numbers and times are sample data.

Tags on each wireframe: **MUST**, **WOW**, **STRETCH** (the tiers from the brief) and **TBD** (the sources don't decide it, so the wireframe shows a proposal).

Full sheet: [wireframes/wireframes.png](wireframes/wireframes.png). Source: [wireframes/wireframes.html](wireframes/wireframes.html).

## A. Setup (first launch)

Empty setup, contacts in priority order, permission prompts.

![Setup](wireframes/setup.png)

## B. Trigger and listen

Home, Listening, and the understanding step (Whisper plus local LLM, keyword fallback).

![Trigger and listen](wireframes/listen.png)

## C. Alone mode

The injured person is speaking. The sources list no dedicated screen, so all three are proposals.

![Alone mode](wireframes/alone.png)

## D. Guide mode

Guide step, general script, CPR mode, end of script and help-on-the-way reminder.

![Guide mode](wireframes/guide.png)

## E. Fallbacks

Message composer, no GPS fix, weak voice or AI. The alert is sent in every case.

![Fallbacks](wireframes/fallback.png)

## F. After and the contact's side

Incident record, the contact's SMS and call, the "PAPUNTA NA" reply (Stretch), and a queued-SMS state for no signal (proposed).

![After and contact](wireframes/after.png)

## G. Quick triggers and confirmations (proposed)

Not in the original brief. Quick triggers outside the app (Lock Screen control, Action Button, Back Tap, "Hey Siri, Saklolo", Home Screen widget) run the Shortcut: location, SMS to all contacts, call #1. A 5-second cancel countdown protects against accidental taps. Passive triggers (fall, shout) ask "Okay ka lang?" first, and silence sends the alert. A "false alarm" text lets the user tell contacts it was a mistake.

![Quick triggers and confirmations](wireframes/triggers.png)

## Screen map

| From | To | When |
| --- | --- | --- |
| Setup (A) | Home (B1) | After saving name and contacts |
| Home | Listening (B2) | Red button, or "Tulong" / "Saklolo" heard |
| Listening | Understanding (B3) | Recording ends (15s max) |
| Understanding | Guide (D1) | Mode is guide |
| Understanding | Alone (C1) | Mode is alone |
| Alone | Escalation (C3) | No reply for 30s |
| Guide or Alone | Incident (F1) | End of incident (trigger TBD) |
| Incident | Home | Return path TBD |
| Lock Screen control, Action Button, widget (G1, G2) | Cancel countdown (G3) | Quick trigger tapped; sends after 5s unless cancelled |
| Fall or shout detected (G4) | Alert or stand down | "Okay ka lang?" 10s: silence sends, "okay" cancels |
| Alert sent, then cancelled | False alarm text (G5) | User chooses to tell contacts |

## Not decided in the sources (TBD)

- **Locked phone:** whether the Shortcut can send SMS and place a call from the Lock Screen. Test with a real SIM.
- **Confirm window** (10s), **countdown** (5s), **retry interval** and **false-alarm wording**.
- **Alone mode:** what the phone says, and what the 30s escalation does.
- **Call confirm:** `tel://` needs one tap, which an injured person may not be able to give.
- **CPR mode:** pace, layout, and how it starts and stops.
- **Source and disclaimer:** where they sit on screen. The Guide wireframes show a footer.
- **Navigation:** how users reach Setup and past Incidents from Home, and how Incident returns to Home.
- **Permissions:** whether prompts appear at first launch or first use.
- **Reminders:** how often "help is on the way" is spoken.
- **Suggestions, not in the brief:** the "stop" and "alert now" buttons on Listening, the retry link on a failed SMS, and the empty-state of Setup.
