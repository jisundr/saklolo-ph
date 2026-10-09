import SwiftUI

/// Home: big red SAKLOLO button + "Listening" status, per the brief's Screens table.
struct HomeView: View {
    @State private var isListening = false
    @State private var showSetup = false
    @State private var showLog = false
    @State private var incident: Incident?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text(isListening ? "Listening..." : "Ready")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Button {
                    // TODO: check-in prompt (TTS) and the Shortcut SMS + call, per brief step 1-3.
                    isListening = true
                } label: {
                    Text("SAKLOLO")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 220, height: 220)
                        .background(Circle().fill(.red))
                }
                .accessibilityLabel("Saklolo. Press to trigger an emergency alert.")

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Contacts and setup", systemImage: "person.2") { showSetup = true }
                        Button("Past incidents", systemImage: "clock.arrow.circlepath") { showLog = true }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Menu")
                }
            }
            .sheet(isPresented: $showSetup) {
                SetupView()
            }
            .fullScreenCover(isPresented: $isListening) {
                // TODO: drop the canned transcript once WhisperKit works (spike 004).
                ListeningView(fallbackTranscript: "Tulong! May sunog sa bahay namin") { saved in
                    incident = saved
                    isListening = false
                }
            }
            .navigationDestination(item: $incident) { saved in
                IncidentView(incident: saved)
            }
            .navigationDestination(isPresented: $showLog) {
                IncidentLogView()
            }
        }
    }
}

#Preview {
    HomeView()
}
