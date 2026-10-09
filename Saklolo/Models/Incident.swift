import Foundation
import SwiftData

enum IncidentMode: String, Codable {
    case alone
    case guide
}

/// One triggered emergency: what was heard, what Saklolo understood, and
/// where. Maps to the brief's Data model: Incident(id, trigger, mode,
/// transcript, summary, script_id, lat, lng, started_at).
@Model
final class Incident {
    var id: UUID
    /// "voice" (heard "Tulong") or "button" (big red button tap).
    var trigger: String
    var mode: IncidentMode
    var transcript: String
    var summary: String
    var scriptID: String?
    var lat: Double?
    var lng: Double?
    var startedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Alert.incident)
    var alerts: [Alert] = []

    init(
        id: UUID = UUID(),
        trigger: String,
        mode: IncidentMode,
        transcript: String = "",
        summary: String = "",
        scriptID: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        startedAt: Date = .now
    ) {
        self.id = id
        self.trigger = trigger
        self.mode = mode
        self.transcript = transcript
        self.summary = summary
        self.scriptID = scriptID
        self.lat = lat
        self.lng = lng
        self.startedAt = startedAt
    }
}
