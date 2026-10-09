import Foundation

/// How the alert shows in the chat thread (F3): "I've told ..." with the
/// exact text that went out, or a fallback when it did not.
extension AlertOutcome {
    var chatMessages: [ChatMessage] {
        switch delivery {
        case .sent:
            return [ChatMessage(role: .saklolo, kind: .alert("\(toldLine)\n\u{201C}\(message)\u{201D}"))]
        case .sendFailed:
            return [
                .saklolo("I couldn't send the alert text."),
                ChatMessage(role: .saklolo, kind: .fallback(.sendFailed)),
            ]
        case .queued:
            return [ChatMessage(role: .saklolo, kind: .fallback(.noSignal))]
        }
    }

    /// "I've told Kuya Ben and Tita Lina". With no contacts saved in the app
    /// the Shortcut still holds its own list, so it names no one.
    private var toldLine: String {
        recipientNames.isEmpty
            ? "I've sent the alert"
            : "I've told \(recipientNames.formatted(.list(type: .and)))"
    }
}
