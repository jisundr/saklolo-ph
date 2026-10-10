import SwiftUI

/// One entry in the chat thread: the person's words on the right, Saklolo's
/// fixed replies on the left, the alert as the delivered banner (F2, F3).
struct ChatMessageRow: View {
    let message: ChatMessage
    /// The mockup's `.xl` bubbles: while listening and in alone mode.
    var large = false

    var body: some View {
        switch message.kind {
        case .text(let text):
            bubble(text)
        case .alert(let told, let sentText, let chips, let at):
            DeliveredAlertView(told: told, sentText: sentText, chips: chips, at: at)
        case .fallback(let kind):
            FallbackCardView(kind: kind)
        }
    }

    private func bubble(_ text: String) -> some View {
        let isUser = message.role == .user
        let role: ChatBubble.Role = isUser ? .outgoing : .incoming
        // Two branches, not one bubble with `large:` passed through:
        // ChatBubble's @ScaledMetric keeps the base size it was first built
        // with, so the size change when the thread leaves listening needs a
        // separate view.
        return VStack(spacing: 0) {
            if large {
                ChatBubble(text, role: role, large: true)
            } else {
                ChatBubble(text, role: role)
            }
        }
        .accessibilityElement(children: .ignore)
            .accessibilityLabel(isUser ? "You said: \(text)" : "Saklolo: \(text)")
    }
}

/// The delivered banner, the one renderer for it: in the thread
/// (`ChatMessage.Kind.alert`) and in a fallback card once its alert is
/// confirmed. "✓ I've told Kuya Ben and Tita Lina · 7:42 PM" at the alert's
/// own time, the chips the alert recorded, then the exact text.
struct DeliveredAlertView: View {
    let told: String
    let sentText: String?
    let chips: [DeliveryChip]
    let at: Date

    init(told: String, sentText: String?, chips: [DeliveryChip], at: Date) {
        self.told = told
        self.sentText = sentText
        self.chips = chips
        self.at = at
    }

    init(_ outcome: AlertOutcome) {
        self.init(told: outcome.toldLine, sentText: outcome.message, chips: outcome.deliveryChips, at: outcome.timestamp)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DeliveredBanner("\(told) \u{00B7} \(at.formatted(date: .omitted, time: .shortened))")
            if !chips.isEmpty {
                // One row when it fits, else one chip per line (large type).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { chipViews }
                    VStack(alignment: .leading, spacing: 6) { chipViews }
                }
            }
            if let sentText {
                SentTextBox(sentText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chipViews: some View {
        ForEach(chips, id: \.text) { chip in
            switch chip {
            // The call still waits on iOS's confirm tap: under way, not done.
            case .calling: StatusPill(chip.text, systemImage: "phone")
            default: StatusPill(chip.text, systemImage: "checkmark", tone: .done)
            }
        }
    }
}

#Preview {
    VStack(spacing: Metrics.gap) {
        ChatMessageRow(message: .saklolo("What happened?"))
        ChatMessageRow(message: .user("Help! Papa fell, his head is bleeding."))
        TypingDots()
        ChatMessageRow(message: ChatMessage(role: .saklolo, kind: .alert(
            told: "I've told Kuya Ben and Tita Lina",
            sentText: "SAKLOLO: Papa fell. 7:42 PM.",
            chips: [.location, .textSent, .calling("Kuya Ben")],
            at: .now
        )))
        ChatMessageRow(message: .saklolo(ChatReplies.aloneHere), large: true)
    }
    .padding()
    .saklaloGround()
}
