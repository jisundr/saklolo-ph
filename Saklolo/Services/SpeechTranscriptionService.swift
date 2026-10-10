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

    /// How long Whisper gets once recording stops. Past it the session
    /// carries on as "could not understand" (F5) rather than keep waiting.
    static let transcriptionTimeout: Duration = .seconds(4)

    /// Set by `stopRecording()`; the recorder checks it every tick.
    private var stopRequested = false

    /// Ends the current recording now (the Done button), so the session goes
    /// straight on to transcribing. Harmless if called twice, or after the
    /// recording has already ended.
    func stopRecording() {
        stopRequested = true
    }

    /// Records until the person stops talking, taps Done, or `maxDuration`,
    /// and returns what they said: "" when nothing but silence or Whisper's
    /// non-speech markers came back, when the model is not loaded yet, or
    /// when Whisper takes longer than `transcriptionTimeout`.
    func transcribe(
        maxDuration: TimeInterval = 15,
        onEvent: (@Sendable (Event) -> Void)? = nil
    ) async throws -> String {
        stopRequested = false
        guard await AVAudioApplication.requestRecordPermission() else {
            throw TranscriptionError.microphoneDenied
        }
        let clock = ContinuousClock()
        let recordingStarted = clock.now
        let url = try await record(upTo: maxDuration, onEvent: onEvent)
        defer { try? FileManager.default.removeItem(at: url) }
        let recordingEnded = clock.now
        print("[004] recorded \(recordingEnded - recordingStarted)\(stopRequested ? " (Done)" : "")")

        onEvent?(.transcribing)
        // A model still downloading or compiling can take minutes: never
        // wait on it here. Start it for next time and let F5 take over.
        guard let pipe else {
            if loading == nil {
                Task { try? await self.prepare() }
            }
            return ""
        }
        let path = url.path
        let raw = await firstResult(within: Self.transcriptionTimeout) {
            try? await pipe.transcribe(
                audioPath: path,
                decodeOptions: DecodingOptions(language: "tl", detectLanguage: false)
            ).map(\.text).joined(separator: " ")
        }
        print("[004] transcribed in \(clock.now - recordingEnded)\(raw == nil ? " (timed out)" : "")")
        return Self.speech(in: raw ?? "")
    }

    /// The words in a Whisper transcript, without its non-speech markers
    /// ("[BLANK_AUDIO]", "(silence)", "<|endoftext|>"); "" when no letter or
    /// digit is left ("...", "…", "?!").
    nonisolated static func speech(in raw: String) -> String {
        let unmarked = raw.replacingOccurrences(
            of: #"\[[^\]]*\]|\([^)]*\)|<\|[^|]*\|>"#,
            with: " ",
            options: .regularExpression
        )
        let text = unmarked.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return text.contains(where: { $0.isLetter || $0.isNumber }) ? text : ""
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
        var endpoint = EndOfSpeech(startedAt: clock.now)
        while recorder.isRecording, !stopRequested {
            try await Task.sleep(for: .milliseconds(100))
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            onEvent?(.level(min(max((power + 60) / 60, 0), 1)))

            switch endpoint.update(power: power, at: clock.now, stopRequested: stopRequested) {
            case .keepRecording: break
            case .speechStarted: onEvent?(.speechDetected)
            case .stop: recorder.stop()
            }
        }
        recorder.stop()
        return url
    }
}

/// When to stop recording: on Done, about 1.4 s after the person goes
/// quiet, or after 8 s with nothing loud enough heard.
struct EndOfSpeech {
    enum Decision: Equatable {
        case keepRecording
        /// The first loud-enough sound; keep recording.
        case speechStarted
        case stop
    }

    /// Dropping below this (dB) counts as quiet; above it, as speech.
    static let speechThreshold: Float = -38
    /// Stop this long after the person goes quiet.
    static let trailingSilence: Duration = .milliseconds(1400)
    /// Give up if nothing loud enough is heard in this long.
    static let noSpeechTimeout: Duration = .seconds(8)

    let startedAt: ContinuousClock.Instant
    private var spoke = false
    private var quietSince: ContinuousClock.Instant?

    init(startedAt: ContinuousClock.Instant) {
        self.startedAt = startedAt
    }

    mutating func update(power: Float, at now: ContinuousClock.Instant, stopRequested: Bool = false) -> Decision {
        if stopRequested { return .stop }
        if power > Self.speechThreshold {
            quietSince = nil
            guard !spoke else { return .keepRecording }
            spoke = true
            return .speechStarted
        }
        if spoke {
            let since = quietSince ?? now
            quietSince = since
            return now - since >= Self.trailingSilence ? .stop : .keepRecording
        }
        return now - startedAt >= Self.noSpeechTimeout ? .stop : .keepRecording
    }
}
