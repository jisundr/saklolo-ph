import AVFoundation
import Foundation
import WhisperKit

/// On-device speech-to-text via WhisperKit. Records from the mic, then
/// transcribes the file. Never blocks the SMS/call path: callers treat any
/// throw as "fall back to the keyword classifier" (see SituationClassifierService).
///
/// The model downloads once on first use (needs network), then is cached on
/// the device. Call `prepare()` early (e.g. at app launch) so the 15s of
/// recording is not spent waiting for it. The model size is the stack
/// fallback lever if Taglish accuracy or latency is bad on the demo device.
// Only ever used from inside `SpeechTranscriptionService`, which serialises access.
extension WhisperKit: @retroactive @unchecked Sendable {}

actor SpeechTranscriptionService {
    enum TranscriptionError: Error {
        case microphoneDenied
        case recordingFailed
    }

    static let shared = SpeechTranscriptionService()

    /// Whisper model folder in the whisperkit-coreml repo.
    static let modelVariant = "openai_whisper-small"

    private var pipe: WhisperKit?
    private var loading: Task<WhisperKit, Error>?

    /// Loads the model, downloading it on first run (needs network). Later
    /// launches find it on disk and work offline. Safe to call repeatedly:
    /// concurrent callers share one load. `onProgress` gets 0...1 while
    /// downloading and is not called when the model is already on disk.
    func prepare(onProgress: (@Sendable (Double) -> Void)? = nil) async throws {
        if pipe != nil { return }
        let task = loading ?? Task {
            let folder: String
            if let cached = Self.cachedModelFolder() {
                folder = cached.path
            } else {
                folder = try await WhisperKit.download(variant: Self.modelVariant) { progress in
                    onProgress?(progress.fractionCompleted)
                }.path
            }
            return try await WhisperKit(WhisperKitConfig(modelFolder: folder, download: false))
        }
        loading = task
        do {
            pipe = try await task.value
        } catch {
            loading = nil
            throw error
        }
    }

    /// WhisperKit's default download location, checked so launches without
    /// network do not need to ask the Hugging Face hub anything.
    private static func cachedModelFolder() -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let folder = documents
            .appending(path: "huggingface/models/argmaxinc/whisperkit-coreml")
            .appending(path: modelVariant)
        let encoder = folder.appending(path: "AudioEncoder.mlmodelc")
        return FileManager.default.fileExists(atPath: encoder.path) ? folder : nil
    }

    /// What the recorder is doing, for the Listening screen's mic indicator.
    enum Event: Sendable {
        /// Mic level, 0...1, about ten times a second.
        case level(Float)
        /// The first loud-enough sound since recording started.
        case speechDetected
        /// Recording is finished; Whisper is working.
        case transcribing
    }

    /// Dropping below this (dB) counts as quiet; above it, as speech.
    private static let speechThreshold: Float = -38
    /// Stop this long after the person goes quiet.
    private static let trailingSilence: Duration = .milliseconds(1400)
    /// Give up if nothing loud enough is heard in this long.
    private static let noSpeechTimeout: Duration = .seconds(8)

    /// Records until the person stops talking (or `maxDuration`) and returns
    /// the transcript.
    func transcribe(
        maxDuration: TimeInterval = 15,
        onEvent: (@Sendable (Event) -> Void)? = nil
    ) async throws -> String {
        guard await AVAudioApplication.requestRecordPermission() else {
            throw TranscriptionError.microphoneDenied
        }
        let url = try await record(upTo: maxDuration, onEvent: onEvent)
        defer { try? FileManager.default.removeItem(at: url) }

        onEvent?(.transcribing)
        try await prepare()
        guard let pipe else { return "" }
        let results = try await pipe.transcribe(
            audioPath: url.path,
            decodeOptions: DecodingOptions(language: "tl", detectLanguage: false)
        )
        return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func record(upTo maxDuration: TimeInterval, onEvent: (@Sendable (Event) -> Void)?) async throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)
        defer { try? session.setActive(false) }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("saklolo-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record(forDuration: maxDuration) else { throw TranscriptionError.recordingFailed }

        let clock = ContinuousClock()
        let started = clock.now
        var spoke = false
        var quietSince: ContinuousClock.Instant?
        while recorder.isRecording {
            try await Task.sleep(for: .milliseconds(100))
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            onEvent?(.level(min(max((power + 60) / 60, 0), 1)))

            let now = clock.now
            if power > Self.speechThreshold {
                if !spoke {
                    spoke = true
                    onEvent?(.speechDetected)
                }
                quietSince = nil
            } else if spoke {
                let since = quietSince ?? now
                quietSince = since
                if now - since >= Self.trailingSilence { break }
            } else if now - started >= Self.noSpeechTimeout {
                break
            }
        }
        recorder.stop()
        return url
    }
}
