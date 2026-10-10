import SwiftUI
import SwiftData

/// Incident log (J1): past incidents, newest first, stored on this phone only.
/// Each incident is a card; empty state (J3), swipe to delete one, "Delete all" with a confirm.
struct IncidentLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Incident.startedAt, order: .reverse) private var incidents: [Incident]
    @State private var confirmDeleteAll = false

    var body: some View {
        Group {
            if incidents.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(incidents) { incident in
                        row(for: incident)
                            .background {
                                // Hidden link: keeps the whole card tappable without the list's chevron.
                                NavigationLink { IncidentView(incident: incident) } label: { EmptyView() }
                                    .opacity(0)
                            }
                            .cardRow()
                    }
                    .onDelete(perform: delete)

                    VStack(spacing: 4) {
                        Text("Kept on this phone only. No audio is recorded.")
                            .font(Typography.finePrint)
                            .foregroundStyle(Palette.textDim)
                            .multilineTextAlignment(.center)
                        Button { confirmDeleteAll = true } label: {
                            Text("Delete all")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Palette.text)
                                .frame(maxWidth: .infinity, minHeight: Metrics.minTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .cardRow()
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .saklaloGround()
        .navigationTitle("Incidents")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete all incidents?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Delete all", role: .destructive, action: deleteAll)
        } message: {
            Text("Every incident on this phone will be removed. This can't be undone.")
        }
    }

    /// J3: before the first incident.
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Palette.textDim)
                .frame(width: 110, height: 110)
                .overlay(Circle().strokeBorder(Palette.line, lineWidth: 3))
                .accessibilityHidden(true)
            Text("No incidents yet")
                .font(Typography.title)
                .foregroundStyle(Palette.text)
            Text("When you use Saklolo, a record of what happened is kept here, on this phone only.")
                .font(.body)
                .foregroundStyle(Palette.textDim)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Metrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(for incident: Incident) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(IncidentText.when(incident.startedAt))
                    .font(.subheadline)
                    .foregroundStyle(Palette.textDim)
                Text(IncidentText.summary(incident))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(3)
                Text(IncidentText.modeLine(incident))
                    .font(.subheadline)
                    .foregroundStyle(Palette.textDim)
                let told = IncidentText.toldCount(incident)
                if told > 0 {
                    StatusPill(IncidentText.toldPill(told), systemImage: "checkmark", tone: .done)
                        .padding(.top, 2)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the incident.")
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

private extension View {
    /// A list row with the list's own chrome removed, so the card is the only surface.
    func cardRow() -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: Metrics.gutter, bottom: 6, trailing: Metrics.gutter))
    }
}

/// What counts as something said. Speech can come back as "..." or "?!"
/// for silence; that is treated like nothing heard.
enum SpokenText {
    /// True when the text has at least one letter or digit.
    static func hasWords(_ text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }
}

/// Wording shared by the incident log (J1) and detail (J2).
enum IncidentText {
    /// "Today · 7:42 PM", "Yesterday · 9:15 PM", "Oct 3 · 9:15 PM"; the year is added outside the current one.
    static func when(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        "\(day(date, now: now, calendar: calendar)) · \(time(date))"
    }

    /// The detail's line drops "Today" (J2 "7:42 PM · Guide · Heavy bleeding") but keeps any other day.
    static func detailLine(_ incident: Incident, now: Date = .now, calendar: Calendar = .current) -> String {
        let when = calendar.isDate(incident.startedAt, inSameDayAs: now)
            ? time(incident.startedAt)
            : self.when(incident.startedAt, now: now, calendar: calendar)
        return "\(when) · \(modeLine(incident))"
    }

    static func summary(_ incident: Incident) -> String {
        SpokenText.hasWords(incident.summary) ? incident.summary : "No summary"
    }

    /// "Guide · Heavy bleeding", "Alone · Fall, can't move"; the mode alone when no script was picked.
    static func modeLine(_ incident: Incident) -> String {
        let mode = incident.mode == .alone ? "Alone" : "Guide"
        guard let id = incident.scriptID, let title = scriptTitle(id: id) else { return mode }
        return "\(mode) · \(title)"
    }

    /// Contacts whose text really went out (a send time is recorded). Unconfirmed rows don't count.
    static func toldCount(_ incident: Incident) -> Int {
        Set(incident.alerts.filter { $0.smsSentAt != nil }.map(\.contactID)).count
    }

    static func toldPill(_ count: Int) -> String {
        count == 1 ? "1 contact told" : "\(count) contacts told"
    }

    private static func day(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return sameYear
            ? date.formatted(.dateTime.month(.abbreviated).day())
            : date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// The script's title in the database in use (scripts are not kept in the store).
    private static func scriptTitle(id: String) -> String? {
        DatabaseStore.shared.active.title(id: id)
    }
}

#Preview("Log") {
    let container = try! ModelContainer(
        for: Incident.self, Alert.self, Contact.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let guide = Incident(trigger: "button", mode: .guide, summary: "Papa fell, his head is bleeding", scriptID: "bleeding")
    let alone = Incident(
        trigger: "button", mode: .alone, summary: "Maria fell and can't move", scriptID: "fall",
        startedAt: .now.addingTimeInterval(-7 * 86_400)
    )
    container.mainContext.insert(guide)
    container.mainContext.insert(alone)
    for _ in 0..<3 {
        container.mainContext.insert(Alert(incident: guide, contactID: UUID(), smsSentAt: .now))
    }
    return NavigationStack { IncidentLogView() }
        .modelContainer(container)
}

#Preview("Empty") {
    NavigationStack { IncidentLogView() }
        .modelContainer(for: [Incident.self, Alert.self, Contact.self], inMemory: true)
}
