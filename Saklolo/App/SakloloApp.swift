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

    var body: some Scene {
        WindowGroup {
            RootView()
                // The Saklolo Shortcut's x-callback-url result (AlertCallback).
                .onOpenURL { AlertQueue.shared.handle($0) }
        }
        .modelContainer(sharedModelContainer)
    }
}
