import SwiftUI
import SwiftData

/// Incident detail (J2): when and which mode, summary, transcript, contacts notified, location.
/// Pushed onto Home's navigation stack, from the incident log or after a session ends.
struct IncidentView: View {
    let incident: Incident

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var contacts: [Contact]
    @State private var confirmDelete = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.gap) {
                Text(IncidentText.detailLine(incident))
                    .font(.subheadline)
                    .foregroundStyle(Palette.textDim)

                SectionCard(title: "Summary") {
                    Text(incident.summary.isEmpty ? "No summary yet." : incident.summary)
                        .font(.body)
                }

                // Stored data, so it stays even though the mockup omits it.
                SectionCard(title: "Transcript") {
                    Text(incident.transcript.isEmpty ? "No transcript." : incident.transcript)
                        .font(.body)
                }

                contactsSection

                if let lat = incident.lat, let lng = incident.lng {
                    locationLine(lat: lat, lng: lng)
                }

                Button("Delete") { confirmDelete = true }
                    .buttonStyle(SaklaloActionStyle(kind: .secondary))
                    .padding(.top, 12)
                    .accessibilityHint("Asks before removing this incident from the phone.")
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, Metrics.gap)
        }
        .saklaloGround()
        .navigationTitle("Incident")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete this incident?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(incident)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("The summary and transcript are removed from this phone. Texts already sent cannot be taken back.")
        }
    }

    @ViewBuilder
    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contacts notified")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.textDim)
                .accessibilityAddTraits(.isHeader)
            if incident.alerts.isEmpty {
                Text("No texts were sent.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textDim)
            } else {
                ForEach(Array(sortedAlerts.enumerated()), id: \.element.id) { index, alert in
                    let contact = contact(for: alert.contactID)
                    // At accessibility sizes the status moves under the name, where it has the row's width.
                    let stacked = typeSize.isAccessibilitySize
                    ContactChip(
                        position: contact.map { $0.priority + 1 } ?? index + 1,
                        name: contact?.name ?? "Removed contact",
                        caption: stacked ? DeliveryStatus.text(for: alert) : nil,
                        relation: nil,
                        trailing: stacked ? nil : AnyView(DeliveryStatus(alert: alert))
                    )
                }
            }
        }
    }

    private func locationLine(lat: Double, lng: Double) -> some View {
        let coordinates = "\(lat.formatted(.number.precision(.fractionLength(4)))), \(lng.formatted(.number.precision(.fractionLength(4))))"
        return HStack(spacing: 4) {
            Text("Location · \(coordinates)")
                .foregroundStyle(Palette.textDim)
            if let url = URL(string: "https://maps.apple.com/?ll=\(lat),\(lng)") {
                Text("·").foregroundStyle(Palette.textDim).accessibilityHidden(true)
                Link(destination: url) {
                    Text("Open in Maps")
                        .fontWeight(.semibold)
                        .underline()
                        .foregroundStyle(Palette.text)
                        .frame(minHeight: Metrics.minTarget)
                        .contentShape(Rectangle())
                }
            }
        }
        .font(.subheadline)
    }

    /// Alerts in contact priority order; removed contacts go last.
    private var sortedAlerts: [Alert] {
        incident.alerts.sorted {
            (contact(for: $0.contactID)?.priority ?? .max) < (contact(for: $1.contactID)?.priority ?? .max)
        }
    }

    private func contact(for id: UUID) -> Contact? {
        contacts.first(where: { $0.id == id })
    }
}

/// What really happened for one contact. Only a recorded send time counts as sent: without one the
/// text may still be unconfirmed, so it reads "not sent yet", never "failed" or "queued" (not recorded).
private struct DeliveryStatus: View {
    let alert: Alert

    var body: some View {
        HStack(spacing: 6) {
            if alert.smsSentAt != nil {
                mark("SMS")
            } else {
                Text("SMS not sent yet")
                    .foregroundStyle(Palette.textDim)
            }
            if alert.called {
                Text("·").foregroundStyle(Palette.textDim).accessibilityHidden(true)
                mark("Call")
            }
        }
        .font(.footnote.weight(.semibold))
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func mark(_ label: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
            Image(systemName: "checkmark").fontWeight(.bold)
        }
        .foregroundStyle(Palette.delivered)
    }

    private var accessibilityText: String {
        var parts = [alert.smsSentAt != nil ? "Text sent" : "Text not sent yet"]
        if alert.called { parts.append("Called") }
        return parts.joined(separator: ", ")
    }

    /// Plain-text form for the chip's caption line at accessibility sizes.
    static func text(for alert: Alert) -> String {
        var parts = [alert.smsSentAt != nil ? "SMS sent" : "SMS not sent yet"]
        if alert.called { parts.append("Called") }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Incident.self, Alert.self, Contact.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ben = Contact(name: "Kuya Ben", phone: "1", relation: "Brother", priority: 0)
    let lina = Contact(name: "Tita Lina", phone: "2", relation: "Aunt", priority: 1)
    let ruel = Contact(name: "Ruel", phone: "3", relation: "Neighbor", priority: 2)
    let incident = Incident(
        trigger: "button", mode: .guide,
        transcript: "Help! Papa fell, his head is bleeding.",
        summary: "Papa fell, his head is bleeding, he is awake.",
        scriptID: "bleeding", lat: 14.6507, lng: 121.0494
    )
    [ben, lina, ruel].forEach { container.mainContext.insert($0) }
    container.mainContext.insert(incident)
    container.mainContext.insert(Alert(incident: incident, contactID: ben.id, smsSentAt: .now, called: true))
    container.mainContext.insert(Alert(incident: incident, contactID: lina.id, smsSentAt: .now))
    container.mainContext.insert(Alert(incident: incident, contactID: ruel.id))
    return NavigationStack { IncidentView(incident: incident) }
        .modelContainer(container)
}
