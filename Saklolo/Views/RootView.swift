import SwiftUI

/// Launch flow: splash (A1) for about a second, then Home (E1) straight away.
/// The listening model loads in the background the whole time and Home shows
/// its state in the status pill (E2); nothing waits on it.
struct RootView: View {
    /// How long the splash stays up. It never waits on the model.
    static let splashDuration: Duration = .seconds(1)

    @StateObject private var modelLoader = ModelLoader()
    @State private var showSplash = true

    /// Written by setup when it finishes.
    @AppStorage("setupCompleted") private var setupCompleted = false
    /// Lets setup be closed for this session without marking it done, so it
    /// comes back on the next launch until it is finished.
    @State private var setupDismissed = false

    var body: some View {
        // A ZStack, not a Group: modifiers on a Group apply to each child, and
        // the model must load only once.
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                HomeView()
                    .fullScreenCover(isPresented: showSetup) {
                        SetupView()
                    }
            }
        }
        .environmentObject(modelLoader)
        .task { await modelLoader.start() }
        .task {
            try? await Task.sleep(for: Self.splashDuration)
            withAnimation(.easeOut(duration: 0.25)) { showSplash = false }
        }
    }

    private var showSetup: Binding<Bool> {
        Binding(
            get: { !setupCompleted && !setupDismissed },
            set: { isPresented in
                if !isPresented { setupDismissed = true }
            }
        )
    }
}

#Preview {
    RootView()
}
