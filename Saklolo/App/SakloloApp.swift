import SwiftUI
import SwiftData

@main
struct SakloloApp: App {
    @StateObject private var modelLoader = ModelLoader()
    @State private var showLoading = true

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
            if showLoading {
                LoadingView(loader: modelLoader) { showLoading = false }
            } else {
                HomeView()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
