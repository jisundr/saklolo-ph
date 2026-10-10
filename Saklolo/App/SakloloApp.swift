import SwiftUI
import SwiftData

@main
struct SakloloApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Contact.self,
            FirstAidScript.self,
            Incident.self,
            Alert.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Reads the bundled database and any cached update now, at launch,
        // so the first alert never waits on that disk read.
        _ = DatabaseStore.shared
        // Update checks: at launch, on return to the foreground, and when
        // signal comes back. Each returns at once; none runs on the alert path.
        if let updater = DatabaseUpdater.shared {
            NetworkMonitor.shared.addSignalReturnObserver { updater.trigger() }
            updater.trigger()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // The Saklolo Shortcut's x-callback-url result (AlertCallback).
                .onOpenURL { AlertQueue.shared.handle($0) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { DatabaseUpdater.shared?.trigger() }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
