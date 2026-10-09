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

    /// Records up to `maxDuration` seconds and returns the transcript.
    func transcribe(maxDuration: TimeInterval = 15) async throws -> String {
        guard await AVAudioApplication.requestRecordPermission() else {
            throw TranscriptionError.microphoneDenied
        }
        let url = try await record(for: maxDuration)
        defer { try? FileManager.default.removeItem(at: url) }

        try await prepare()
        guard let pipe else { return "" }
        let results = try await pipe.transcribe(
            audioPath: url.path,
            decodeOptions: DecodingOptions(language: "tl", detectLanguage: false)
        )
        return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func record(for duration: TimeInterval) async throws -> URL {
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
        guard recorder.record(forDuration: duration) else { throw TranscriptionError.recordingFailed }
        try await Task.sleep(for: .seconds(duration))
        recorder.stop()
        return url
    }
}
