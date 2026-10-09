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
    static let modelVariant = "openai_whisper-large-v3-v20240930_turbo_632MB"

    private var pipe: WhisperKit?
    private var loading: Task<WhisperKit, Error>?

    /// Where `prepare` is, for the loading screen.
    enum Stage: Sendable {
        /// Fetching the model, 0...1. Only on the first run.
        case downloading(Double)
        /// Loading the model. The first time, CoreML compiles it for the
        /// Neural Engine, which takes minutes and reports no progress.
        case compiling
        /// One silent transcription through the whole pipeline.
        case testing
    }

    /// Set once a load has fully succeeded, so the loading screen only warns
    /// about the long wait when it is real. The OS can still drop its compile
    /// cache (for example after an update), so this is a hint, not a promise.
    static var hasLoadedBefore: Bool {
        get { UserDefaults.standard.bool(forKey: "whisperLoaded.\(modelVariant)") }
        set { UserDefaults.standard.set(newValue, forKey: "whisperLoaded.\(modelVariant)") }
    }

    /// Loads the model, downloading it on first run (needs network). Later
    /// launches find it on disk and work offline. Safe to call repeatedly:
    /// concurrent callers share one load, and only the first caller's
    /// `onStage` is called.
    func prepare(onStage: (@Sendable (Stage) -> Void)? = nil) async throws {
        if pipe != nil { return }
        let task = loading ?? Task {
            if let cached = Self.cachedModelFolder() {
                do {
                    return try await Self.load(from: cached.path, onStage: onStage)
                } catch {
                    // Unreadable (corrupt or old) copy: drop it and download again.
                    try? FileManager.default.removeItem(at: cached)
                }
            }
            onStage?(.downloading(0))
            let folder = try await WhisperKit.download(variant: Self.modelVariant) { progress in
                onStage?(.downloading(progress.fractionCompleted))
            }
            return try await Self.load(from: folder.path, onStage: onStage)
        }
        loading = task
        do {
            pipe = try await task.value
            Self.hasLoadedBefore = true
        } catch {
            loading = nil
            throw error
        }
    }

    private static func load(from folder: String, onStage: (@Sendable (Stage) -> Void)?) async throws -> WhisperKit {
        let pipe = try await WhisperKit(WhisperKitConfig(modelFolder: folder, load: false, download: false))
        onStage?(.compiling)
        try await pipe.loadModels()
        // Silence through the whole pipeline proves it works end to end, so a
        // failure shows up on the loading screen and not during an emergency.
        onStage?(.testing)
        _ = try await pipe.transcribe(audioArray: [Float](repeating: 0, count: 16_000))
        return pipe
    }

    /// WhisperKit's default download location, only if every model's
    /// weights are on disk. A download that was interrupted leaves the
    /// `.mlmodelc` folders behind without their weights, so checking for the
    /// folders alone treats a half-downloaded model as ready. Launches
    /// without network rely on this instead of asking the Hugging Face hub.
    private static func cachedModelFolder() -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let folder = documents
            .appending(path: "huggingface/models/argmaxinc/whisperkit-coreml")
            .appending(path: modelVariant)
        let complete = ["MelSpectrogram", "AudioEncoder", "TextDecoder"].allSatisfy { name in
            let weights = folder.appending(path: "\(name).mlmodelc/weights/weight.bin")
            return FileManager.default.fileExists(atPath: weights.path)
        }
        return complete ? folder : nil
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
