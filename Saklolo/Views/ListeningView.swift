import SwiftUI
import SwiftData

/// Listening: "Ano'ng nangyari?" with live transcript, per the brief's Screens table.
/// Transcribes, classifies with `SituationClassifierService`, and saves an `Incident`.
/// The SMS and call do not wait on this screen (PRD FR-9): classification only
/// decides which first-aid script and mode the guide uses.
struct ListeningView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var transcript: String = ""
    @State private var secondsRemaining = 15
    @State private var classification: SituationClassification?

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

            Text(transcript.isEmpty ? "..." : transcript)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(minHeight: 80)
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            if let classification {
                VStack(spacing: 4) {
                    Text(classification.summary)
                        .font(.headline)
                    Text("\(classification.mode.rawValue) · \(classification.scriptID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            } else {
                Text("\(secondsRemaining)s")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .task {
            // TODO: live countdown and partial transcript while recording.
            let heard = (try? await SpeechTranscriptionService.shared.transcribe()) ?? ""
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

#Preview {
    ListeningView(fallbackTranscript: "Tulong! Nahulog si Lola sa hagdan, hindi makagalaw")
        .modelContainer(for: [Incident.self, Alert.self, Contact.self, FirstAidScript.self], inMemory: true)
}
