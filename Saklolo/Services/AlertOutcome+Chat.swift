import Foundation

/// How the alert shows in the chat thread (F3): "I've told ..." with the
/// exact text that went out, or a fallback card when it did not (I1, I3),
/// then a card when the location is not live (I4). Cards, not pop-ups, so
/// the guide stays visible.
extension AlertOutcome {
    static let keepGuiding = "I'll keep guiding you."
    static let firstAidStillWorks = "First aid still works. I'll keep guiding you."

    var chatMessages: [ChatMessage] {
        var messages: [ChatMessage]
        switch delivery {
        case .sent:
            messages = [ChatMessage(role: .saklolo, kind: .alert(toldText))]
        case .sendFailed:
            messages = [ChatMessage(role: .saklolo, kind: .fallback(.sendFailed))]
        case .queued:
            messages = [ChatMessage(role: .saklolo, kind: .fallback(.noSignal))]
        }
        if noLocationLastKnown {
            messages.append(ChatMessage(role: .saklolo, kind: .fallback(.noLocation)))
        }
        switch delivery {
        case .sent: break
        case .sendFailed: messages.append(.saklolo(Self.keepGuiding))
        case .queued: messages.append(.saklolo(Self.firstAidStillWorks))
        }
        return messages
    }

    /// "I've told Kuya Ben and Tita Lina" and the text, as in F3.
    var toldText: String {
        "\(toldLine)\n\u{201C}\(message)\u{201D}"
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
