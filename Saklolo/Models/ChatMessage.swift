import Foundation

/// One entry in the chat thread (F1 to F3). Lives only for the session; the
/// saved record is the `Incident`, so this is never persisted.
struct ChatMessage: Identifiable, Equatable, Sendable {
    enum Role: Sendable {
        /// What the person said (their transcript).
        case user
        /// A fixed reply from the app. Never model-written text.
        case saklolo
    }

    enum Kind: Equatable, Sendable {
        /// A plain bubble.
        case text(String)
        /// The delivered banner (F3): "I've told ..." at the alert's own
        /// time (the one in the text), chips built only from what the alert
        /// recorded, and the exact text that went out. Only for an alert
        /// known to be sent: the thread swaps the `.fallback` card for this
        /// once `AlertQueue` confirms it (`AlertOutcome.confirming(_:at:)`).
        case alert(told: String, sentText: String?, chips: [DeliveryChip], at: Date)
        /// A failure card that keeps the guide visible (T7 renders these).
        case fallback(FallbackKind)
    }

    let id: UUID
    let role: Role
    let kind: Kind

    init(id: UUID = UUID(), role: Role, kind: Kind) {
        self.id = id
        self.role = role
        self.kind = kind
    }

    static func saklolo(_ text: String) -> ChatMessage {
        ChatMessage(role: .saklolo, kind: .text(text))
    }

    static func user(_ text: String) -> ChatMessage {
        ChatMessage(role: .user, kind: .text(text))
    }
}

/// The ways sending can fall short (I1 to I4). Defined here so the thread's
/// shape is fixed; the cards themselves come with the fallback work.
enum FallbackKind: Equatable, Sendable {
    /// Handed to the Shortcut, not confirmed yet: "Sending the alert ...".
    /// Turns into "I've told ..." on confirmation, or into the send-failed
    /// card (I1) on failure or silence.
    case sending
    /// The Shortcut could not send the text by itself (I1).
    case sendFailed
    /// Offer the system message composer instead (I2).
    case composer
    /// No signal: the text is queued and retried (I3).
    case noSignal
    /// No fresh location: the last known one is sent, labelled (I4).
    case noLocation
}

/// One chip under the delivered banner (mockup `.pills`): only what the
/// alert really recorded.
enum DeliveryChip: Equatable, Sendable {
    /// The text went out (the banner is only shown once it did).
    case textSent
    /// A live location went with the text. Never for a last known or
    /// missing fix.
    case location
    /// The call to contact #1 was placed (iOS still asks to confirm it).
    case calling(String)

    var text: String {
        switch self {
        case .textSent: "Text sent"
        case .location: "Location"
        case .calling(let name): "Calling \(name)"
        }
    }
}
