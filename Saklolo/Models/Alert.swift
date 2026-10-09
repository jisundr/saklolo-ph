import Foundation
import SwiftData

/// Delivery record for one contact on one incident. Maps to the brief's
/// Data model: Alert(id, incident_id, contact_id, sms_sent_at, called).
@Model
final class Alert {
    var id: UUID
    var incident: Incident?
    var contactID: UUID
    var smsSentAt: Date?
    var called: Bool

    init(id: UUID = UUID(), incident: Incident? = nil, contactID: UUID, smsSentAt: Date? = nil, called: Bool = false) {
        self.id = id
        self.incident = incident
        self.contactID = contactID
        self.smsSentAt = smsSentAt
        self.called = called
    }
}
