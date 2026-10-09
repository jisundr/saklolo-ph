import SwiftUI

/// Incident: summary, contacts notified, delivery status, per the brief's Screens table.
struct IncidentView: View {
    let incident: Incident

    var body: some View {
        NavigationStack {
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
                                Text(alert.contactID.uuidString.prefix(8))
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
            }
            .navigationTitle("Incident")
        }
    }
}

#Preview {
    IncidentView(incident: Incident(trigger: "button", mode: .guide, summary: "Papa fell, his head is bleeding."))
}
