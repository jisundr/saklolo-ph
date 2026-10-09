# Saklolo — Project Brief

Oct 9, 2026 · @Jayson De los Reyes · AppBuildersPH Hackathon 2026 (theme: Local AI) · Solo

## The story

My dad had an accident, and his phone wasn't with him. My mom panicked and didn't know what to do. Thankfully my brother knew first aid and helped him. He's okay now.

But what if you're alone? Or the person with you doesn't know what to do?

## Overview

**Pitch:** Saklolo is an offline voice assistant for emergencies. It listens, it calls for help, and it guides whoever is there through first aid until help arrives.

**Pitch line:** "Hindi lang humihingi ng tulong. Tinuturo kung ano'ng gagawin habang wala pa ang tulong."

**Problem:** In an accident, two things go wrong:
1. **The phone is out of reach**, or there's no data, so no one gets alerted.
2. **The person who is there panics** and doesn't know first aid, and there's no time to search online.

Existing safety features (Apple/Google fall detection, Emergency SOS, Life360) need a wearable, a button press, or internet, and they only send an alert. None of them tell the person in the room what to do.

**Solution:** An iPhone app that hears "Tulong!", works out what happened from free-form Taglish, and then does two things at once:
- **Alerts** the nearest contacts by SMS with a clear summary and GPS, then calls them (cell network only, no internet)
- **Guides** the person present through vetted first-aid steps, out loud, one step at a time

**Why local AI (submission answer):** Emergencies happen where there's no data: inside homes with weak signal, during typhoons, in provinces, on prepaid load with no data promo. Speech recognition, understanding the situation, and first-aid guidance must work instantly and offline, so they run on the phone. Only SMS and calls use the cell network. Local also means no audio from inside someone's home goes to a server, and it costs nothing per use.

**vs Apple Emergency SOS:** Apple calls 911 and shares your location. It doesn't understand Taglish, doesn't say what happened, doesn't alert the neighbor first, and doesn't tell your panicking family what to do.

## Target users

| User | Situation | What they need most |
| --- | --- | --- |
| Families caring for older parents (primary) | A parent gets hurt; the spouse or family member panics | Calm, step-by-step guidance + alert others |
| Elderly living alone | Kids work in Manila or abroad | Help without reaching the phone; neighbor alerted first |
| Families in flood/typhoon areas | Data down, trapped or hurt at home | A message rescuers can act on |

Secondary users are the contacts who receive the alert: neighbors, barangay officials, family.

## Two modes

| | Alone mode | Guide mode |
| --- | --- | --- |
| Who's speaking | The injured person | A companion (spouse, child, neighbor) |
| Example | "Tulong, nadulas ako, di ako makatayo" | "Tulong! Nahulog si Papa, dumudugo ang ulo!" |
| Saklolo does | Alerts contacts, calls #1, keeps talking to the person | Alerts contacts in the background AND talks the companion through first aid |
| No reply | Escalates after 30s: "Walang sagot pagkatapos bumagsak" | — |

The AI picks the mode from what it hears ("nahulog **ako**" vs "nahulog **si Papa**").

## Core flow

1. **Trigger:** "Tulong" / "Saklolo" heard, or big red button
2. **Check-in:** phone speaks "Ano'ng nangyari?"
3. **Listen:** records up to 15s
4. **Understand (local AI):** Whisper transcribes Taglish; local LLM returns JSON: mode (alone/guide), situation, matching first-aid script, urgency, one-line summary
5. **Alert (always):** SMS to contacts in priority order with summary + GPS, then call contact #1
6. **Guide (guide mode):** speak the matched first-aid script one step at a time; companion says "okay" / "tapos na" to continue, or "ulitin" to repeat; it reminds them help is on the way
7. **Log:** incident saved with transcript, script used, and delivery status

**Example SMS:**
> SAKLOLO: Si Papa nahulog, dumudugo ang ulo, gising pa. 7:42pm. Lokasyon: maps.apple.com/?ll=14.6507,121.0494

## First-aid scripts (safety rule)

**The LLM never writes medical instructions.** It only classifies the situation. The steps come from fixed scripts based on Philippine Red Cross basic first aid, stored as JSON, and every script starts by making sure help is being called.

MVP scripts (max 4):

| Script | Triggered by | Key steps |
| --- | --- | --- |
| Fall, can't move | nahulog, nadulas, di makagalaw | Don't move them, keep head still, keep warm, watch breathing |
| Heavy bleeding | dumudugo, sugat, maraming dugo | Clean cloth, press firmly, don't lift to check, add more cloth on top |
| Unconscious | walang malay, di gumigising | Tap and shout, check breathing; if not breathing, start CPR with a count |
| Head injury | tumama ang ulo, nauntog | Keep still, stop bleeding with gentle pressure, watch for vomiting/confusion |

If nothing matches: general script (stay calm, check breathing, don't move them, help is coming).

**Before submission:** check every script against Philippine Red Cross first-aid material and show the source in the app. Add a one-line disclaimer: "Gabay lang ito. Hindi ito kapalit ng doktor o rescuer."

## MVP scope

**Must have (core loop)**
- [ ] Setup: user name, 1–5 contacts with priority order
- [ ] Big red "SAKLOLO" button (demo safety net)
- [ ] Check-in prompt via AVSpeechSynthesizer
- [ ] On-device speech-to-text with WhisperKit
- [ ] On-device LLM classification (JSON output)
- [ ] Keyword fallback if the LLM fails or is slow (never block the SMS)
- [ ] Offline GPS via CoreLocation
- [ ] SMS to all contacts via a Shortcut, then call contact #1
- [ ] Guide mode: step-by-step first-aid script, voice "okay/ulitin" + big Next/Repeat buttons
- [ ] Incident screen: transcript, summary, delivery status

**The wow (right after the core loop)**
- [ ] Voice trigger: "Tulong" while the app is open
- [ ] CPR mode: spoken count and metronome beep at the right pace

**Stretch, only if ahead**
- [ ] Fall detection with CoreMotion + silence escalation
- [ ] Contacts reply "PAPUNTA NA" and the phone announces it

**Cut (pitch as the roadmap)**
- Android, smartwatch, background listening with the app closed
- More scripts (burns, choking, stroke signs, seizures), Bisaya/Ilocano
- Barangay responder mode, family dashboard

## Stack (iOS)

| Layer | Choice | Fallback |
| --- | --- | --- |
| App | SwiftUI, Xcode | — |
| Speech-to-text | WhisperKit (on-device Whisper, multilingual) | Smaller Whisper model; big red button |
| Understanding | Apple Foundation Models (on-device; needs Apple Intelligence iPhone, 15 Pro or newer) | Gemma/Qwen via MLX Swift or llama.cpp; then keyword rules |
| First-aid content | Bundled JSON scripts | — |
| TTS | AVSpeechSynthesizer (Filipino voice if installed) | Pre-recorded clips |
| Location | CoreLocation (GPS works offline) | Last known location |
| SMS | App opens a Shortcut (`shortcuts://run-shortcut?name=Saklolo&input=text`); its Send Message action with "Show When Run" off sends without a tap | MFMessageComposeViewController (one tap to send) |
| Call | `tel://` (one confirm tap) | — |
| Storage | SwiftData | UserDefaults |

**Needs:** a Mac with Xcode and your Apple ID to install on your iPhone. **Permissions:** Microphone, Location (When In Use), Motion if fall detection makes it.

## Screens

| Screen | Purpose |
| --- | --- |
| Setup | Name, contacts, priority order |
| Home | Big red SAKLOLO button, "Nakikinig" status |
| Listening | "Ano'ng nangyari?" with live transcript |
| Guide | One big step at a time, Next/Repeat, "Na-text na sina Kuya at Tita" banner |
| Incident | Summary, contacts notified, delivery status |

## Data model

| Entity | Key fields |
| --- | --- |
| Contact | id, name, phone, relation, priority |
| Script | id, title, keywords, steps[] (bundled JSON) |
| Incident | id, trigger, mode, transcript, summary, script_id, lat, lng, started_at |
| Alert | id, incident_id, contact_id, sms_sent_at, called |

## Build timeline (now → 10am)

| Time | Focus |
| --- | --- |
| 4:45–5:30pm | Xcode project, install on iPhone, contacts screen |
| 5:30–8pm | Red button → Shortcut SMS + call + GPS working end to end |
| 8–9pm | First-aid scripts JSON + Guide screen with TTS and Next/Repeat |
| 9–11pm | WhisperKit: speak → transcript → keyword match → script |
| 11pm–1am | On-device LLM JSON classification (mode, script, summary) + fallback |
| 1–5am | Sleep |
| 5–7am | Voice trigger, CPR metronome, UI polish |
| 7–8am | Full test with a real SIM and contact; **feature freeze 8am** |
| 8–9am | ~1 min demo video, README, disclosures, check scripts against Red Cross material |
| 9–10am | Make repo public, post on X/LinkedIn (tag Devin/Cognition, #AppBuildersPH), submit once |

## Pitch (5 min + 3 min Q&A, solo, keynote style)

One idea per slide, big type, lots of silence. The deck is "Saklolo Pitch" (15 slides, script in the speaker notes).

1. **Story (~60s):** My dad had an accident. → His phone wasn't with him. → My mom panicked. → My brother knew first aid. → But what if he wasn't there?
2. **The gap (~15s):** Calling for help isn't enough. Someone has to know what to do until help arrives.
3. **Reveal (~30s):** So I built Saklolo. → It listens. It calls. It guides.
4. **Live demo (~2 min):** "Let me show you."
5. **Why local (~40s):** No internet. → The AI lives on the phone. → The AI never makes up first aid.
6. **Close (~15s):** So no one faces an emergency alone. → Salamat.

**Solo demo setup:**
- iPhone mirrored to the projector (AirPlay or QuickTime via the Mac)
- Wi-Fi off and cellular data off on screen; cellular on for SMS
- A pillow as "Papa" and a towel as the cloth
- An organizer or audience member saved as the emergency contact (ask before your slot); they read the SMS out loud
- Fallbacks: big red button if voice fails; backup video if everything fails

## Submission checklist

**Where and when:** cerebralvalley.ai/e/appbuildersph-hackathon-2026 · **10:00 AM, Oct 10**, no extensions · submit **once** (no edits or resubmits) · code freezes at 10:00 and judges review the repo as of the deadline.

**The project**
- [ ] Project name: Saklolo
- [ ] Short description (use the pitch above)
- [ ] Team members: Jayson De los Reyes (solo), name exactly as on appbuildersph.com/hackathon
- [ ] Public GitHub repository, public **before** 10:00
- [ ] README with how judges can build and run it (deploying is not required)

**The proof**
- [ ] Demo video, about 1 minute
- [ ] X or LinkedIn video post URL (required): tag Devin / Cognition and include #AppBuildersPH
- [ ] What runs locally: speech-to-text (Whisper), situation classification (on-device LLM), first-aid guidance, GPS
- [ ] What requires internet: nothing. SMS and calls use the cell network only

**The disclosures**
- [ ] Models used: Whisper (WhisperKit model size), Apple Foundation Models or Gemma/Qwen
- [ ] Technologies and frameworks: SwiftUI, WhisperKit, Foundation Models / MLX Swift, CoreLocation, Shortcuts
- [ ] APIs and cloud services: none for the AI; carrier SMS and calls
- [ ] Existing code and assets: any pre-starter code; first-aid content source (Philippine Red Cross basic first aid)
- [ ] AI development tools: Claude Code

**Must answer:** Why does this product benefit from running AI locally? (Use the "Why local AI" paragraph above.)

**Before you hit submit**
- [ ] Repo builds from a fresh clone using the README
- [ ] Video plays and the X/LinkedIn post is public
- [ ] Every field filled; read it all once more (one submission only)

## Demo Day (Oct 10, Cyberzone SM Makati)

- [ ] Arrive by **12:00 PM** registration; AV check at 12:15 (test mirroring and an SMS on site)
- [ ] Finalists announced at 1:00 PM; you must be there in person to be a finalist
- [ ] Bring: laptop, iPhone with a loaded SIM, charger, HDMI/USB-C adapter, pillow and towel for the demo, backup video on the laptop
- [ ] Line up your emergency contact (organizer or audience member) before your slot
- [ ] Pitch is 5 min + 3 min Q&A

## Risks

| Risk | Fallback |
| --- | --- |
| No Mac / Xcode | Blocker for iOS. Borrow a Mac or switch to Android (emulator + borrowed phone) |
| iPhone can't run Apple's on-device model | Gemma/Qwen via MLX Swift; else keyword rules (disclose honestly) |
| Shortcut silent send doesn't work | MFMessageComposeViewController with one tap |
| Medical advice concerns from judges | Fixed vetted scripts, LLM only classifies, source shown, disclaimer, always calls for help |
| Whisper slow or weak on Taglish | Smaller model; keyword fallback; big red button |
| No signal at Cyberzone | Test SMS during AV check; backup video |
| "Why not Apple SOS?" | It doesn't understand Taglish, say what happened, or guide the person in the room |

## Open questions

- [ ] Do you have a Mac with Xcode?
- [ ] Which iPhone model (decides Apple's on-device model vs MLX)?
- [ ] Who is the emergency contact at the demo?
- [ ] GitHub repo link for the last slide
