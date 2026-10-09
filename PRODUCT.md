# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Stack

SwiftUI + SwiftData, iOS 17+, iPhone only (project.yml, XcodeGen). Already scaffolded under `Saklolo/`.

## Users

Primary: a panicking family member in the room when an older parent falls or is hurt; and the injured person themselves, alone, phone out of reach, speaking aloud. Context: family caring for older parents, elderly living alone, flood/typhoon households with no data.
Secondary: the contacts who receive the SMS and call (neighbors, barangay officials, family).
The user's hands may be shaking or bloody, their attention is on a person, not the screen, and the screen is often read from arm's length or heard instead of read.

## Product Purpose

Offline voice assistant for emergencies. Hears "Tulong" / "Saklolo" (Taglish), texts and calls contacts with a summary and GPS, then speaks vetted first-aid steps one at a time until help arrives. Success: contacts are alerted and the person present is never left without a next step. Built for the AppBuildersPH Hackathon 2026 (Local AI), solo entry, deadline 10:00 AM Oct 10, 2026.

## Positioning

Phone-native fall detection and Emergency SOS only alert; none tell the person in the room what to do, understand Taglish, or work with no data. Saklolo alerts the neighbor first and then coaches the family, with all AI on-device.

## Operating Context

Screens: Setup, Home (big red SAKLOLO button), Listening (live transcript), Guide (one big step, Next/Repeat, "Na-text na sina Kuya at Tita" banner), Incident. Alone mode, guide mode, CPR mode (spoken count and metronome). Wireframes in `docs/wireframes/`.

## Capabilities and Constraints

- Steps come only from fixed scripts based on Philippine Red Cross basic first aid; the LLM only classifies, never writes medical instructions.
- Required disclaimer: "Gabay lang ito. Hindi ito kapalit ng doktor o rescuer." Script source shown in-app.
- Voice is the primary channel (AVSpeechSynthesizer); screen is the backup.
- Language: Taglish, warm and direct. App name pronounced sak-LO-lo ("help!").
- Offline: no web fonts, no remote assets.

## Brand Commitments

Name "Saklolo". The big red SAKLOLO button is fixed. Otherwise a free hand (confirmed by the user).

## Evidence on Hand

PRD, USER-FLOW, and 19 low-fi wireframes in `docs/`. No logo, no brand assets, no user testing. Do not invent testimonials or statistics.

## Product Principles

1. One thing at a time: one step, one action, one voice.
2. Never block the alert: the SMS goes out whatever else fails.
3. Calm is a feature: the interface lowers the user's pulse, it never matches their panic.
4. Honest about being a guide, not a doctor.
5. Works with nothing: no data, no hands, no time to read.

## Accessibility & Inclusion

Elders and stressed users: very large type that follows Dynamic Type, 44pt minimum targets (much larger for primary actions), high contrast in sunlight and in a dark room at night, never color-only meaning, Reduce Motion honored, VoiceOver labels. Filipino-first copy.
