import SwiftUI
import SwiftData

/// Incident log (J1): past incidents, newest first, stored on this phone only.
/// Empty state (J3), swipe to delete one, "Delete all" with a confirm (J4).
struct IncidentLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Incident.startedAt, order: .reverse) private var incidents: [Incident]
    @State private var confirmDeleteAll = false

    var body: some View {
        Group {
            if incidents.isEmpty {
                ContentUnavailableView(
                    "No past incidents",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("When you use Saklolo, each incident is saved here, on this phone only.")
                )
            } else {
                List {
                    ForEach(incidents) { incident in
                        NavigationLink {
                            IncidentView(incident: incident)
                        } label: {
                            row(for: incident)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Past incidents")
        .toolbar {
            if !incidents.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete all", role: .destructive) { confirmDeleteAll = true }
                }
            }
        }
        .confirmationDialog("Delete all incidents?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Delete all", role: .destructive, action: deleteAll)
        } message: {
            Text("Every incident on this phone will be removed. This can't be undone.")
        }
    }

    private func row(for incident: Incident) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(incident.summary.isEmpty ? "No summary" : incident.summary)
                .lineLimit(2)
            Text(incident.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(incidents[index])
        }
        try? modelContext.save()
    }

    private func deleteAll() {
        for incident in incidents {
            modelContext.delete(incident)
        }
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        IncidentLogView()
    }
    .modelContainer(for: [Incident.self, Alert.self, Contact.self], inMemory: true)
}
