# Finding 004: WhisperKit transcription of Taglish on the iPhone

Spike 004 in [SPIKES.md](../SPIKES.md). Date: 2026-10-09. Device: iPhone 15 Pro Max, iOS 18.7.3, wired to a Mac running Xcode 27. WhisperKit from `argmax-oss-swift` 1.1.1.

## Verdict

**Partly validated. Not signed off.** On-device transcription works and is fast with the large-v3 turbo model. The one sentence tried on it came back with the words that choose the first-aid script right. But only 3 sentences were spoken in total, 1 of them on the chosen model, and the 12-utterance pass criteria in SPIKES.md were not run. The model also takes about 3 minutes to prepare on first launch, which needs a decision (see "What this changes").

## What was measured

### Model comparison, same sentence, same speaker

Said: "Tulong! Nahulog si Lola sa hagdan, hindi makagalaw, please pumunta kayo dito!"

| Model | What it wrote | Transcribe time |
| --- | --- | --- |
| `openai_whisper-small` (about 216 MB) | "Tulong, na hulog siya lala sa Aktan ang 5 kagalaw, dispumunta kayo dito." | 1.6 s |
| `openai_whisper-large-v3-v20240930_turbo_632MB` | "Tulong! Nahulog si Lola sa agdaan. Hindi makagalaw. Please bumunta kayo dito." | 0.9 s |

Turbo is closer on every word that matters: "nahulog" and "Lola" are right. "hagdan" came out as "agdaan". `small` split "nahulog" into "na hulog", which a keyword match on "nahulog" would miss.

Other `small` results (before the model change):

| Said | `small` wrote |
| --- | --- |
| Help, may dumudugo sa braso ko, maraming dugo, mag-isa lang ako | "Hey, may tumudug na sabaraso ko. Maraming dugo. Mugi silang ako." (1.5 s) |
| (a short sentence) | "Tudong... Tudong..." (0.8 s) |

Only the first sentence was repeated on turbo. The other two were not.

### Time to get the model ready

| Case | Time |
| --- | --- |
| First run of the turbo model, load happened inside the first transcription | 201.8 s, then an empty transcript |
| Fresh install of a new build, with the self-test added | 179.8 s |
| Relaunch of the same build | 10.6 s |

The long wait is CoreML compiling the model for the Neural Engine. It was cached across launches. After reinstalling the app it came back once. Not tested: a clean install the way a user would get it, or after an iOS update.

The empty transcript on the 202 s run is not explained. The next run worked. It may have been the long first call, or the very short audio of that run.

## Bugs found and fixed

- **Half-downloaded model treated as ready.** The cache check only looked for the `AudioEncoder.mlmodelc` folder, which exists on an interrupted download. CoreML then failed with "Error in reading the MIL network." Seen on the phone: the encoder weights were still a 340 MB `.incomplete` file. Now the check needs the weights of all three models, and an unreadable cached model is deleted and downloaded again.
- **The canned fallback hid failures.** The transcript fell back to a fixed sentence about a fire when transcription failed, so the app always looked like it worked. A diagnostics line now says "heard" or "canned fallback" with the error, and the transcript is logged.
- **Mic and recording.** Recording is metered and stops about 1.4 s after the person stops talking, with a 15 s cap and an 8 s give-up. The Listening screen shows the mic level. The thresholds (-38 dB, 1.4 s) were guesses and were not tuned in a noisy room.

## Models looked at on Hugging Face, not tried

| Model | Base | License | Held-out error (its own card) |
| --- | --- | --- | --- |
| `sapinsapin/whisper-small-pld-fil` | small | Apache-2.0 | 8.6% words, 3.6% characters |
| `sapinsapin/whisper-large-v3-pld-fil-norm` | large-v3 | CC-BY-NC (non-commercial) | about 12% words |
| `beabucayan/lingkodai-whisper-fil` | medium | none stated | none given |
| `michaelildefonso/whisper_taglish` | none | MIT | empty repo |

All are PyTorch, not CoreML, so WhisperKit cannot load them without converting them with `whisperkittools`. All were trained on clean read Filipino speech, not on panicked or code-switched Taglish. Their error rates come from different test sets and are not comparable with each other or with ours. Best next candidate if turbo disappoints: `whisper-small-pld-fil` (clear license, same speed as `small`).

## Not tested

- The 12 utterances from spike 001, and any pass rate against "most pick the right script".
- Airplane mode: that a cached model loads and transcribes with no network.
- Noise, a quieter voice, or a second speaker.
- Whether the keyword classifier copes with turbo's spelling mistakes. "na hulog"-style spacing errors were seen on `small`; a space-tolerant match was suggested and not built.
- Memory pressure on long use. The turbo model loaded and ran, and no memory kill showed up in the phone's crash logs during the session.

## What this changes

1. **Use turbo for now.** `SpeechTranscriptionService.modelVariant` is set to the 632 MB turbo build.
2. **PRD.** "Only SMS and calls use the network" is no longer true. The first launch downloads about 632 MB. The PRD's assumptions and risks need a line for this.
3. **The 3-minute first run needs a product decision.** Options: do it at onboarding, ship the model inside the app, or accept it. Until decided, install the final build and open it once, online, before any demo.
4. **The loading screen is a temporary form.** It shows the steps (download, prepare, test), an elapsed timer, and a first-run estimate, and always keeps an emergency bypass. Open design questions for the redesign: a "still loading" sign on Home after the bypass, and what the user sees if the model never loads.
5. **Pass criteria for 004 are still open.** Run the 12 utterances on turbo, record the script match rate, then update SPIKES.md.

## Where the code is

`Saklolo/Services/SpeechTranscriptionService.swift`, `Saklolo/Services/ModelLoader.swift`, `Saklolo/Views/LoadingView.swift`, `Saklolo/Views/ListeningView.swift`. Uncommitted at the time of writing: the loading screen steps and timer, and the self-test.
