import Foundation

/// Drives the loading screen: tracks the Whisper model download/load so the
/// UI can show progress. The alert itself never depends on this finishing.
@MainActor
final class ModelLoader: ObservableObject {
    enum Phase: Equatable {
        case downloading(Double)
        case loading
        case ready
        case failed
    }

    @Published private(set) var phase: Phase = .loading

    func start() async {
        phase = .loading
        do {
            try await SpeechTranscriptionService.shared.prepare { [weak self] fraction in
                Task { @MainActor in self?.phase = .downloading(fraction) }
            }
            phase = .ready
        } catch {
            phase = .failed
        }
    }
}
