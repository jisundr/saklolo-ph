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
        /// "I've told ..." with the alert text that went out (T6).
        case alert(String)
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
    /// The Shortcut could not send the text by itself (I1).
    case sendFailed
    /// Offer the system message composer instead (I2).
    case composer
    /// No signal: the text is queued and retried (I3).
    case noSignal
    /// No fresh location: the last known one is sent, labelled (I4).
    case noLocation
}
