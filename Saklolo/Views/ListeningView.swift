import SwiftUI

/// Listening: "Ano'ng nangyari?" with live transcript, per the brief's Screens table.
/// Wires up to SpeechTranscriptionService (WhisperKit) — placeholder transcript for now.
struct ListeningView: View {
    @State private var transcript: String = ""
    @State private var secondsRemaining = 15

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

            Text("\(secondsRemaining)s")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            // TODO: SpeechTranscriptionService.start() — records up to 15s,
            // transcribes with WhisperKit, then hands off to the
            // SituationClassifierService per brief step 3-4.
        }
    }
}

#Preview {
    ListeningView()
}
