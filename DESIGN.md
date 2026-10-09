---
name: Saklolo
description: "Isigaw mo lang. Kami na ang tatawag." An offline emergency voice assistant with a numbered, color-coded signal identity.
colors:
  ink: "#0A1222"
  ink-raised: "#131F38"
  ink-line: "#2B3B5E"
  text-on-ink: "#F4F7FD"
  text-dim-on-ink: "#AEBBD6"
  paper: "#F2F5FA"
  paper-raised: "#FFFFFF"
  paper-line: "#CBD5E6"
  text-on-paper: "#0A1222"
  text-dim-on-paper: "#44536F"
  signal-red: "#D81E2B"
  signal-orange: "#FF8A1F"
  signal-yellow: "#FFD21F"
  signal-blue: "#4C9AFF"
  alarm-text-on-ink: "#FF4B55"
  alarm-text-on-paper: "#C4121F"
  delivered-on-ink: "#36D399"
  delivered-on-paper: "#0B7A50"
typography:
  display:
    fontFamily: "Barlow Condensed, Arial Narrow, sans-serif"
    fontSize: "46pt"
    fontWeight: 800
    lineHeight: 1
    letterSpacing: "0.03em"
  signal:
    fontFamily: "Barlow Condensed"
    fontSize: "28pt"
    fontWeight: 800
    letterSpacing: "0.03em"
  step:
    fontFamily: "SF Pro"
    fontSize: "34pt"
    fontWeight: 700
    lineHeight: 1.14
  body:
    fontFamily: "SF Pro"
    fontSize: "17pt"
    fontWeight: 400
    lineHeight: 1.4
  fine-print:
    fontFamily: "SF Pro"
    fontSize: "12pt"
    fontWeight: 400
rounded:
  chip: "14pt"
  button: "18pt"
  full: "9999pt"
spacing:
  gutter: "20pt"
  gap: "12pt"
  min-target: "44pt"
  primary-action: "64pt"
components:
  saklolo-button:
    backgroundColor: "{colors.signal-red}"
    textColor: "#FFFFFF"
    typography: "{typography.display}"
    rounded: "{rounded.full}"
    size: "220pt"
  action-primary:
    backgroundColor: "{colors.text-on-ink}"
    textColor: "{colors.ink}"
    typography: "{typography.signal}"
    rounded: "{rounded.button}"
    height: "64pt"
  action-secondary:
    backgroundColor: "transparent"
    textColor: "{colors.text-on-ink}"
    typography: "{typography.signal}"
    rounded: "{rounded.button}"
    height: "64pt"
  signal-chip-saklolo:
    backgroundColor: "{colors.signal-red}"
    textColor: "#FFFFFF"
    typography: "{typography.signal}"
    rounded: "{rounded.full}"
    height: "34pt"
  contact-chip:
    backgroundColor: "{colors.ink-raised}"
    textColor: "{colors.text-on-ink}"
    typography: "{typography.body}"
    rounded: "{rounded.chip}"
    height: "48pt"
---

# Design System: Saklolo

Platform: iOS (SwiftUI, iOS 17+). Tokens live in `Saklolo/Theme/Theme.swift`; the full visual board is `docs/brand/brand-board.html` (PNG alongside). Product truth is in `PRODUCT.md`.

## Overview

**Creative North Star: "The Signal."** Every Filipino household can read a numbered, color-coded warning in half a second. Saklolo borrows that grammar so a frightened person never has to interpret the screen: one fixed color, one numeral, one word per urgency level, and one enormous red button.

The scene decides the look. Someone is on a bathroom floor or kneeling beside a parent at 2 a.m. in a dark hallway, or in noon glare on a flooded street. Dark night-ink is the default so the screen does not blind; light paper is first-class for sunlight. Signal colors never change between the two.

Calm is a feature. The interface lowers the user's pulse: few words, huge type, one action at a time, no exclamation points, no flashing. Energy comes from the signal colors and the condensed signage type, never from motion or noise.

**Key characteristics:** committed ink ground, four-color signal scale, condensed road-sign display type over plain SF reading type, concentric-ring mark, red reserved for alarm.

## Colors

Strategy: **Committed to a single deep ground with a four-signal scale.** Ink (or paper) owns 70%+ of every screen; signal colors appear as fields only for urgency and the SAKLOLO button.

### Primary
- **Signal Red** (#D81E2B): the SAKLOLO button, level 4 chip, the current step on the strand, and failures. White text on it is 5.1:1.

### Secondary (the signal scale)
- **Signal Orange** (#FF8A1F): level 3, MABILIS. Ink text 7.9:1.
- **Signal Yellow** (#FFD21F): level 2, INGAT. Ink text 12.9:1.
- **Signal Blue** (#4C9AFF): level 1, BANTAY. Ink text 6.6:1.

### Neutral
- **Ink** (#0A1222) ground, **Ink Raised** (#131F38) chips and sheets, **Ink Line** (#2B3B5E) separators; **Text** (#F4F7FD, 17.4:1), **Text Dim** (#AEBBD6, 9.7:1).
- **Paper** (#F2F5FA) ground, **Paper Raised** (#FFFFFF), **Paper Line** (#CBD5E6); **Text** (#0A1222), **Text Dim** (#44536F, 7.1:1).
- **Delivered** (#36D399 on ink, #0B7A50 on paper): only after something actually happened.

### Named Rules
**Red Means Alarm.** Red appears only on the SAKLOLO button, level 4, the active step marker and failures. Calm actions (Next, Ulitin, Setup) are white on ink or ink on paper. If red is everywhere, nothing is urgent.
**Green Means Done.** Delivered green appears only after an SMS delivered or a contact answered. Never decoration, never an optimistic default.
**Never Color Alone.** Urgency always carries numeral + word (+ bar count). Status always carries an icon or word.
**Signal Colors Are Labels, Not Buttons.** Interactive color is white on ink / ink on paper.

## Typography

**Display / signage:** Barlow Condensed (ExtraBold, Bold, SemiBold; SIL OFL, bundled in `Saklolo/Resources/Fonts`). Road-sign proportions put large words on narrow phones and read from arm's length. Used for the wordmark, SAKLOLO button, signal levels, step counters and action labels, always uppercase with +0.03em tracking.
**Reading:** SF Pro via system text styles, so Dynamic Type works. First-aid steps, transcripts, contacts, disclaimers.

### Hierarchy
- **Display** (Barlow 800, 46pt+, uppercase): wordmark, SAKLOLO button.
- **Signal** (Barlow 800, 28pt, uppercase): chips, TAPOS NA / ULITIN, HAKBANG 2 NG 5.
- **Step** (SF Bold, `.largeTitle` 34pt+): the one instruction on screen. Never smaller than 28pt equivalent at default size; scales up with Dynamic Type.
- **Body** (SF, 17pt): contacts, transcript, banners.
- **Fine print** (SF, 12pt minimum): disclaimer and source.

### Named Rules
**One Voice On Screen.** One step, in large type, with room around it. If a screen needs a second sentence of instruction, it belongs on the next step.
**Condensed Is For Short Words.** Barlow is for words of 1 to 3 syllables and numerals. Sentences are SF.

## Layout

20pt gutters, 12pt gaps, system safe areas, standard NavigationStack and sheets (no custom navigation). Primary actions sit in the bottom thumb zone at 64pt tall; every target is at least 44pt. Screens have one focal element: the button on Home, the step on Guide. Spacing is generous around that element and tight between related chips.

## Elevation & Depth

Flat by default. Depth comes from tonal layers (ink, ink-raised) and 1-2pt lines, not shadows. The single exception: the SAKLOLO button carries a soft red lift (offset y 8, blur 14, 40% red) so it reads as pressable in the dark.

## Shapes

Circles for the mark and the SAKLOLO button; continuous rounded rectangles for actions (18pt) and chips (14pt); capsules for signal chips and strand segments. No sharp rectangles, no pills on large buttons.

## Components

### SAKLOLO Button
220pt red circle, Barlow 46pt white label. Three concentric rings sit behind it (orange, yellow, blue) at 30-55% opacity at rest, 70-90% when listening. This is the mark, live.

### Actions
Primary (TAPOS NA): white fill, ink label (inverted on paper). Secondary (ULITIN): 2pt line outline, text color label. Both 64pt tall, full width, Barlow 28pt uppercase.

### Signal Chip
Capsule in the level color, numeral in a disc on the left, word on the right. Ink text on blue/yellow/orange, white on red.

### Step Strand
A row of 8pt capsules, one per step. Done steps are dim, the current step is alarm red, future steps are line color.

### Contact Chip
48pt ink-raised row with a priority tile on the left (1 yellow, 2 orange, 3 blue, ink numeral) and the relation, dim, on the right.

### Banner
Delivered-green tint with a check icon: "Na-text na sina Kuya at Tita".

### Motion: The Ripple
The one authored moment. On trigger the three rings expand outward once from the red core in signal order, ease-out, about 0.9s, then hold. While listening they breathe at low opacity. Nothing else moves unprompted. With Reduce Motion on, the rings appear and hold still.

## Do's and Don'ts

### Do
- Use the signal word with the numeral, always.
- Keep red scarce: button, level 4, current step, failures.
- Write short Taglish, one instruction per step: "Diinan ang sugat."
- Name the action on the button: "Tapos na", not "Next".
- Show the disclaimer and source ("Gabay lang ito. Hindi ito kapalit ng doktor o rescuer.") small, always present on Guide.
- Test every screen in dark, light, and the largest Dynamic Type size.

### Don't
- Don't use red for calm actions, delete, or decoration.
- Don't put the mark's rings or any pattern behind text.
- Don't add exclamation points, "DON'T PANIC", or "EMERGENCY DETECTED".
- Don't claim the AI gives medical advice. Steps come from Red Cross scripts; AI only listens and sorts.
- Don't rotate, outline, gradient or recolor the mark or its red core.
- Don't use gradient text, glassmorphism, or decorative shadows.
- Don't use custom navigation, custom switches or non-SF-Symbol icons.
