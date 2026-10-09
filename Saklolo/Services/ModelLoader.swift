import Foundation

/// Drives the loading screen: tracks the Whisper model download/load so the
/// UI can show progress. The alert itself never depends on this finishing.
@MainActor
final class ModelLoader: ObservableObject {
    enum Phase: Equatable {
        /// Fetching the model, 0...1.
        case downloading(Double)
        case compiling
        case testing
        case ready
        case failed
    }

    @Published private(set) var phase: Phase = .compiling
    /// When this attempt began, for the on-screen timer.
    @Published private(set) var startedAt = Date()
    /// True when the long first-time wait is expected.
    @Published private(set) var isFirstRun = !SpeechTranscriptionService.hasLoadedBefore

    /// True once this attempt had to download the model.
    @Published private(set) var didDownload = false

    func start() async {
        didDownload = false
        phase = .compiling
        startedAt = Date()
        isFirstRun = !SpeechTranscriptionService.hasLoadedBefore
        do {
            try await SpeechTranscriptionService.shared.prepare { [weak self] stage in
                Task { @MainActor in
                    switch stage {
                    case .downloading(let fraction):
                        self?.didDownload = true
                        self?.phase = .downloading(fraction)
                    case .compiling: self?.phase = .compiling
                    case .testing: self?.phase = .testing
                    }
                }
            }
            phase = .ready
            print("[004] model ready in \(Date().timeIntervalSince(startedAt)) s")
        } catch {
            print("[004] model load failed: \(error)")
            phase = .failed
        }
    }
}
