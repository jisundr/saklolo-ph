import Foundation
import SwiftData

/// An emergency contact, in the priority order they should be alerted.
/// Maps to the brief's Data model: Contact(id, name, phone, relation, priority).
@Model
final class Contact {
    var id: UUID
    var name: String
    var phone: String
    var relation: String
    /// Lower = contacted first. Contact #1 (priority 0) also gets the phone call.
    var priority: Int

    init(id: UUID = UUID(), name: String, phone: String, relation: String, priority: Int) {
        self.id = id
        self.name = name
        self.phone = phone
        self.relation = relation
        self.priority = priority
    }
}
