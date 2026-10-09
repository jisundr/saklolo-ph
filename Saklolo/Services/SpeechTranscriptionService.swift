import Foundation

/// On-device speech-to-text via WhisperKit. Placeholder — core loop (red
/// button → Shortcut SMS + call + GPS) ships first per the brief's build
/// timeline; WhisperKit integration is the 9-11pm block.
///
/// Integration notes for whoever picks this up:
/// - Add the WhisperKit package: https://github.com/argmaxinc/WhisperKit
/// - Model size is a stack fallback lever (brief: "Smaller Whisper model" if
///   Taglish accuracy/latency is bad on the demo device).
/// - Must never block the SMS/call path — if transcription is slow or
///   fails, fall straight to the keyword fallback (see
///   SituationClassifierService) rather than waiting.
actor SpeechTranscriptionService {
    enum TranscriptionError: Error {
        case notImplemented
    }

    /// Records up to `maxDuration` seconds and returns the transcript.
    func transcribe(maxDuration: TimeInterval = 15) async throws -> String {
        throw TranscriptionError.notImplemented
    }
}
