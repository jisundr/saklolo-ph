import SwiftUI
import SwiftData

/// Listening: "Ano'ng nangyari?" with live transcript, per the brief's Screens table.
/// Transcribes, classifies with `SituationClassifierService`, and saves an `Incident`.
/// The SMS and call do not wait on this screen (PRD FR-9): classification only
/// decides which first-aid script and mode the guide uses.
struct ListeningView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var transcript: String = ""
    @State private var stage: Stage = .waiting
    @State private var level: Float = 0
    @State private var quietTooLong = false
    @State private var transcribeStarted: ContinuousClock.Instant?
    @State private var classification: SituationClassification?
    /// Spike 004 readout: where the text came from and how long transcription took.
    @State private var diagnostics = ""

    private enum Stage {
        /// Recording, nothing loud enough heard yet.
        case waiting
        /// Recording, voice picked up.
        case hearing
        /// Recording done, Whisper is working.
        case transcribing
        case done
    }

    /// "button" or "voice", stored on the Incident.
    var trigger = "button"
    /// Used when transcription fails or is not implemented yet (WhisperKit is
    /// still a stub), so the rest of the flow can be exercised.
    var fallbackTranscript = ""
    /// Called once with the saved incident, for the parent to navigate to the guide.
    var onClassified: (Incident) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 20) {
            Text("Ano'ng nangyari?")
                .font(.title)
                .bold()

            if stage != .done {
                micIndicator
            }

            Text(transcript.isEmpty ? "..." : transcript)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(minHeight: 80)
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            Text(diagnostics)
                .font(Typography.finePrint)
                .foregroundStyle(Palette.textDim)

            if let classification {
                VStack(spacing: 4) {
                    Text(classification.summary)
                        .font(.headline)
                    Text("\(classification.mode.rawValue) · \(classification.scriptID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            }
        }
        .padding()
        .task {
            var heard = ""
            var failure = ""
            do {
                heard = try await SpeechTranscriptionService.shared.transcribe { event in
                    Task { @MainActor in
                        switch event {
                        case .level(let value): level = value
                        case .speechDetected: stage = .hearing
                        case .transcribing:
                            stage = .transcribing
                            transcribeStarted = .now
                            level = 0
                        }
                    }
                }
            } catch {
                failure = " (\(error))"
            }
            stage = .done
            let source = heard.isEmpty ? "canned fallback\(failure)" : "heard"
            let took = transcribeStarted.map { (ContinuousClock.now - $0).formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1))) }
            diagnostics = [source, took.map { "transcribe+load \($0)" }].compactMap { $0 }.joined(separator: " · ")
            print("[004] \(diagnostics) | transcript: \(heard.debugDescription)")
            transcript = heard.isEmpty ? fallbackTranscript : heard

            // Keyword result is computed first inside classify(); the LLM can
            // refine it but never delays it past its timeout.
            let result = await SituationClassifierService().classify(transcript: transcript)
            classification = result

            let incident = Incident(
                trigger: trigger,
                mode: result.mode,
                transcript: transcript,
                summary: result.summary,
                scriptID: result.scriptID
            )
            modelContext.insert(incident)
            onClassified(incident)
        }
    }
}

extension ListeningView {
    /// The mark's rings swell with the voice. Calm: they move with the level, never flash.
    fileprivate var micIndicator: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Palette.signalRed.opacity(0.9)).frame(width: 56, height: 56)
                ForEach(Array([Palette.signalOrange, Palette.signalYellow, Palette.signalBlue].enumerated()), id: \.offset) { index, color in
                    Circle()
                        .strokeBorder(color.opacity(stage == .hearing ? 0.9 : 0.35), lineWidth: 5)
                        .frame(width: 56 + CGFloat(index + 1) * 26, height: 56 + CGFloat(index + 1) * 26)
                        .scaleEffect(1 + CGFloat(level) * 0.12 * CGFloat(index + 1))
                }
            }
            .frame(width: 220, height: 220)
            .animation(.easeOut(duration: 0.1), value: level)
            .accessibilityHidden(true)

            Text(statusText)
                .font(Typography.body)
                .foregroundStyle(quietTooLong && stage == .waiting ? Palette.alarmText : Palette.textDim)
                .accessibilityLabel(statusText)
        }
        .task(id: stage) {
            quietTooLong = false
            guard stage == .waiting else { return }
            try? await Task.sleep(for: .seconds(3))
            quietTooLong = true
        }
    }

    fileprivate var statusText: String {
        switch stage {
        case .waiting: quietTooLong ? "Walang marinig. Lakasan ang boses." : "Nakikinig..."
        case .hearing: "Naririnig ka. Magsalita lang."
        case .transcribing: "Iniintindi..."
        case .done: ""
        }
    }
}

#Preview {
    ListeningView(fallbackTranscript: "Tulong! Nahulog si Lola sa hagdan, hindi makagalaw")
        .modelContainer(for: [Incident.self, Alert.self, Contact.self, FirstAidScript.self], inMemory: true)
}
