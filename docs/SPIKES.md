# Spikes

Short experiments that settle an assumption before we build on it. Unverified assumptions come from [PRD §8](PRD.md#8-dependencies-assumptions-risks). Deadline: submission closes 10:00 AM, Oct 10, 2026.

Pass criteria below are proposed, not agreed. Edit them before relying on them.

## Done

| # | Spike | Result | Where |
| --- | --- | --- | --- |
| 001 | Apple Foundation Models as the on-device classifier | **Validated for the demo, on a Mac only.** After permissive guardrails, few-shot examples, and a keyword merge: script 36/36, mode 35/36 to 36/36 on 12 hand-written utterances, about 0.76s. The safety guardrail still blocks some injured-child phrasings, so the keyword fallback is required. Not tested on a phone. | `docs/tasks/2026-10-09-1844-research-ondevice-llm-classifier/` |
| 002 | MLX 3B models (Qwen2.5-3B, Llama-3.2-3B) as the classifier | **Not demo-ready.** Script 3 to 6 of 12, tested with a plain prompt and no examples. Llama refused some emergency messages. Not used. | `docs/tasks/2026-10-09-1858-research-mlx-taglish-classifier/` |
| 006 | The iOS app builds and runs end to end | **Passed on the iPhone 15 Pro Max (iOS 18.7.3).** Needed three fixes: regenerate the Xcode project (it was missing `KeywordDatabase` and `keywords.json`), a Swift 6 data-race error in `LocationService`, and a new bundle ID for personal-team signing. The red button was not wired to anything, so it now opens Listening (canned transcript) and then Guide. `keywords.json` is in the bundle. Not checked: `KeywordDatabase.bundled().version` on the device. | commit `438c4d7` |

## To verify

In priority order: a failure early in the list costs the demo the most.

| # | Spike | Why it matters | Proposed pass criteria | Needs |
| --- | --- | --- | --- | --- |
| 003 | Shortcut sends SMS and places a call on a locked phone | This is the alert itself (FR-9). Nothing else matters if it fails. Marked unverified in the PRD. | With the phone locked: SMS reaches all contacts with no tap, and the call to contact #1 is placed (one confirm tap allowed). If it fails, document the unlock fallback (T2). | iPhone with a real SIM |
| 004 | WhisperKit transcription of Taglish on the iPhone 15 Pro Max | The classifier has nothing to read without a transcript. `SpeechTranscriptionService` is a stub that throws, so the app hears nothing; Listening uses a canned transcript. | The 12 test utterances, spoken aloud, transcribe well enough that classification still picks the right script for most of them. Record transcription time after the 15s recording. | Phone, WhisperKit package |
| 005 | Apple Foundation Models on the phone | All spike 001 numbers are from a Mac. **Blocked: the test phone runs iOS 18.7.3, so the model is unavailable there and the app uses the keyword fallback.** Needs iOS 26+ and Apple Intelligence on and downloaded. | Model reports `available`. Median `classify` latency stays under the 3s timeout on the 12 utterances. | Phone on iOS 26+ |
| 007 | Filipino text-to-speech voice | Guide mode reads steps aloud. Marked unverified in the PRD. | A Filipino voice is installed and reads a script step intelligibly. If not, show the text only and say so. | Phone |
| 008 | Quick triggers (stretch): Lock Screen control, Action Button, shout-detection class list | FR-T2, FR-T5. Not needed for the core demo. | Each trigger starts the Shortcut. The sound-classification class list is checked against Apple's docs before relying on it. | Phone, iOS 18+ |

## Open loop outside the spikes

- Keyword list updates over the network are not built. They would need a hosted file and a PRD change, since the PRD says only SMS and calls use the network.
