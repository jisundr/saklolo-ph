# Spikes

Short experiments that settle an assumption before we build on it. Unverified assumptions come from [PRD §8](PRD.md#8-dependencies-assumptions-risks). Deadline: submission closes 10:00 AM, Oct 10, 2026.

Pass criteria below are proposed, not agreed. Edit them before relying on them.

## Done

| # | Spike | Result | Where |
| --- | --- | --- | --- |
| 001 | Apple Foundation Models as the on-device classifier | **Validated for the demo, on a Mac only.** After permissive guardrails, few-shot examples, and a keyword merge: script 36/36, mode 35/36 to 36/36 on 12 hand-written utterances, about 0.76s. The safety guardrail still blocks some injured-child phrasings, so the keyword fallback is required. Not tested on a phone. | `docs/tasks/2026-10-09-1844-research-ondevice-llm-classifier/` |
| 002 | MLX 3B models (Qwen2.5-3B, Llama-3.2-3B) as the classifier | **Not demo-ready.** Script 3 to 6 of 12, tested with a plain prompt and no examples. Llama refused some emergency messages. Not used. | `docs/tasks/2026-10-09-1858-research-mlx-taglish-classifier/` |
| 004 | WhisperKit transcription of Taglish on the iPhone 15 Pro Max | **Partly validated, not signed off.** Works on the phone. The turbo model (`large-v3-v20240930_turbo_632MB`) wrote "Nahulog si Lola sa agdaan" in 0.9 s for a sentence where `small` wrote "na hulog siya lala" in 1.6 s. Only 3 sentences were spoken, 1 on turbo; the 12-utterance pass rate was not run. First launch needs about 3 minutes to prepare the model (10.6 s after) and about 632 MB of download, so the PRD line "only SMS and calls use the network" is no longer true. | [`docs/findings/004-whisperkit-transcription.md`](findings/004-whisperkit-transcription.md) |
| 006 | The iOS app builds and runs end to end | **Passed on the iPhone 15 Pro Max (iOS 18.7.3).** Needed three fixes: regenerate the Xcode project (it was missing `KeywordDatabase` and `keywords.json`), a Swift 6 data-race error in `LocationService`, and a new bundle ID for personal-team signing. The red button was not wired to anything, so it now opens Listening (canned transcript) and then Guide. `keywords.json` is in the bundle. Not checked: `KeywordDatabase.bundled().version` on the device. | commit `438c4d7` |

## To verify

In priority order: a failure early in the list costs the demo the most.

| # | Spike | Why it matters | Proposed pass criteria | Needs |
| --- | --- | --- | --- | --- |
| 003 | Shortcut sends SMS and places a call on a locked phone | This is the alert itself (FR-9). Nothing else matters if it fails. Marked unverified in the PRD. | With the phone locked: SMS reaches all contacts with no tap, and the call to contact #1 is placed (one confirm tap allowed). If it fails, document the unlock fallback (T2). | iPhone with a real SIM |
| 004b | Finish 004: run the 12 utterances on turbo, test airplane mode, and make the keyword match tolerate spacing errors | Closes the open part of 004. | Script matches for most of the 12 (same bar as 004). A cached model loads and transcribes with the phone offline. "na hulog" matches the fall script. | Phone |
| 005 | Apple Foundation Models on the phone | All spike 001 numbers are from a Mac. **Blocked: the test phone runs iOS 18.7.3, so the model is unavailable there and the app uses the keyword fallback.** Needs iOS 26+ and Apple Intelligence on and downloaded. | Model reports `available`. Median `classify` latency stays under the 3s timeout on the 12 utterances. | Phone on iOS 26+ |
| 007 | Text-to-speech voice | Guide mode reads steps aloud. The copy is English now, so the built-in English voice is the default and a Filipino voice is no longer needed. Still to check: it reads a script step intelligibly on the phone. | A built-in English voice reads a script step intelligibly. If not, show the text only and say so. | Phone |
| 008 | Quick triggers (stretch): Lock Screen control, Action Button, shout-detection class list | FR-T2, FR-T5. Not needed for the core demo. | Each trigger starts the Shortcut. The sound-classification class list is checked against Apple's docs before relying on it. | Phone, iOS 18+ |

## Open loop outside the spikes

- Keyword list updates over the network are not built. They would need a hosted file and a PRD change, since the PRD says only SMS and calls use the network.
