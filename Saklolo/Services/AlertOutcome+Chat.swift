import Foundation

/// How the alert shows in the chat thread (F3): "Sending the alert ..." with
/// the exact text while the Shortcut has not confirmed it (the card becomes
/// the "I've told ..." banner only on confirmation, or the send-failed
/// card), or a
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

    /// The one location chip (I4): what the text said in place of a live
    /// location. "Last known location (7:31 PM)", or "Location unavailable"
    /// with no fix at all; nil for a live fix. One chip, not a "No GPS"
    /// chip beside it: both would describe the same missing fix.
    var locationChipText: String? {
        guard let location else { return AlertPolicy.noLocationNote }
        return location.note
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

    /// The chips under the delivered banner, in the mockup's order:
    /// "Location" only for a live fix, "Text sent", and "Calling Kuya Ben"
    /// only when the call was placed.
    var deliveryChips: [DeliveryChip] {
        var chips: [DeliveryChip] = []
        if location?.isLastKnown == false {
            chips.append(.location)
        }
        chips.append(.textSent)
        if let index = records.firstIndex(where: \.called), recipientNames.indices.contains(index) {
            chips.append(.calling(recipientNames[index]))
        }
        return chips
    }

    /// The delivered banner for this alert. It shows the alert's own time
    /// (`timestamp`, the time in the text), not when the confirmation came.
    var delivered: ChatMessage {
        ChatMessage(
            role: .saklolo,
            kind: .alert(told: toldLine, sentText: message, chips: deliveryChips, at: timestamp)
        )
    }

    /// The thread once this alert is confirmed sent: its delivery card
    /// (sending, send failed or no signal) becomes the delivered banner, in
    /// place, so the thread has one banner per incident. Unchanged when the
    /// card is gone or already swapped. `sentAt` (the confirmation) is not
    /// shown: the banner keeps the alert's own time so it matches the text.
    func confirming(_ thread: [ChatMessage], at sentAt: Date) -> [ChatMessage] {
        guard let index = thread.firstIndex(where: { message in
            switch message.kind {
            case .fallback(.sending), .fallback(.sendFailed), .fallback(.noSignal): true
            default: false
            }
        }) else { return thread }
        var updated = thread
        updated[index] = delivered
        return updated
    }

    /// "Kuya Ben, Tita Lina and Ruel", or "your contacts" when none are saved.
    var recipientList: String {
        recipientNames.isEmpty ? "your contacts" : recipientNames.formatted(.list(type: .and))
    }
}
