import Foundation

/// How the alert shows in the chat thread (F3): "Sending the alert ..." with
/// the exact text while the Shortcut has not confirmed it (the card becomes
/// "I've told ..." only on confirmation, or the send-failed card), or a
/// fallback card when it could not even be handed over (I1, I3), then a card
/// when the location is not live (I4). Cards, not pop-ups, so the guide
/// stays visible.
extension AlertOutcome {
    static let keepGuiding = "I'll keep guiding you."
    static let firstAidStillWorks = "First aid still works. I'll keep guiding you."

    var chatMessages: [ChatMessage] {
        var messages: [ChatMessage]
        switch delivery {
        case .awaitingConfirmation:
            messages = [ChatMessage(role: .saklolo, kind: .fallback(.sending))]
        case .sendFailed:
            messages = [ChatMessage(role: .saklolo, kind: .fallback(.sendFailed))]
        case .queued:
            messages = [ChatMessage(role: .saklolo, kind: .fallback(.noSignal))]
        }
        if noLocationLastKnown {
            messages.append(ChatMessage(role: .saklolo, kind: .fallback(.noLocation)))
        }
        switch delivery {
        case .awaitingConfirmation: break
        case .sendFailed: messages.append(.saklolo(Self.keepGuiding))
        case .queued: messages.append(.saklolo(Self.firstAidStillWorks))
        }
        return messages
    }

    /// "Sending the alert to Kuya Ben and Tita Lina..." while unconfirmed.
    var sendingLine: String {
        "Sending the alert to \(recipientList)\u{2026}"
    }

    /// The exact text, in quotes, under the sending and told lines.
    var quotedMessage: String {
        "\u{201C}\(message)\u{201D}"
    }

    /// "I've told Kuya Ben and Tita Lina". With no contacts saved in the app
    /// the Shortcut still holds its own list, so it names no one.
    var toldLine: String {
        recipientNames.isEmpty
            ? "I've sent the alert"
            : "I've told \(recipientNames.formatted(.list(type: .and)))"
    }

    /// "Kuya Ben, Tita Lina and Ruel", or "your contacts" when none are saved.
    var recipientList: String {
        recipientNames.isEmpty ? "your contacts" : recipientNames.formatted(.list(type: .and))
    }
}
