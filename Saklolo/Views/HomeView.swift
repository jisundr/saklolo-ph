import SwiftUI

/// Home: big red SAKLOLO button + "Nakikinig" status, per the brief's Screens table.
struct HomeView: View {
    @State private var isListening = false
    @State private var showSetup = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text(isListening ? "Nakikinig..." : "Handa")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Button {
                    // TODO: trigger the core loop — check-in prompt (TTS),
                    // then start listening (WhisperKit), per brief step 1-3.
                    isListening.toggle()
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
                    Button("Setup") { showSetup = true }
                }
            }
            .sheet(isPresented: $showSetup) {
                SetupView()
            }
        }
    }
}

#Preview {
    HomeView()
}
