import SwiftUI
import SwiftData

/// Incident detail (J2): summary, time, transcript, contacts notified.
/// Pushed onto Home's navigation stack, from the incident log or after a session ends.
struct IncidentView: View {
    let incident: Incident

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var contacts: [Contact]
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section("Summary") {
                Text(incident.summary.isEmpty ? "No summary yet." : incident.summary)
                Text(incident.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Transcript") {
                Text(incident.transcript.isEmpty ? "—" : incident.transcript)
                    .font(.footnote)
            }

            Section("Contacts notified") {
                if incident.alerts.isEmpty {
                    Text("None yet.")
                } else {
                    ForEach(incident.alerts) { alert in
                        HStack {
                            Text(contactName(for: alert.contactID))
                            Spacer()
                            if alert.smsSentAt != nil {
                                Label("SMS sent", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .labelStyle(.iconOnly)
                            }
                            if alert.called {
                                Label("Called", systemImage: "phone.fill")
                                    .foregroundStyle(.blue)
                                    .labelStyle(.iconOnly)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Delete this incident", role: .destructive) { confirmDelete = true }
            } footer: {
                Text("Stored on this phone only. No audio is kept.")
            }
        }
        .navigationTitle("Incident")
        .confirmationDialog("Delete this incident?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(incident)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func contactName(for id: UUID) -> String {
        contacts.first(where: { $0.id == id })?.name ?? "Removed contact"
    }
}

#Preview {
    NavigationStack {
        IncidentView(incident: Incident(trigger: "button", mode: .guide, summary: "Papa fell, his head is bleeding."))
    }
    .modelContainer(for: [Incident.self, Alert.self, Contact.self], inMemory: true)
}
