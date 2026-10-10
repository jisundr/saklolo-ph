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
        case .alert(let told, let sentText, let details, let at):
            delivered(told: told, sentText: sentText, details: details, at: at)
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

    /// "✓ I've told Kuya Ben and Tita Lina · 7:42 PM", the exact text, then
    /// what the alert recorded ("Sent to 2 · Location shared").
    private func delivered(told: String, sentText: String?, details: String?, at: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DeliveredBanner("\(told) \u{00B7} \(at.formatted(date: .omitted, time: .shortened))")
            if let sentText {
                SentTextBox(sentText)
            }
            if let details {
                Text(details)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                            .fill(Palette.groundRaised)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            details: "Sent to 2 \u{00B7} Location shared \u{00B7} Calling Kuya Ben",
            at: .now
        )))
        ChatMessageRow(message: .saklolo(ChatReplies.aloneHere), large: true)
    }
    .padding()
    .saklaloGround()
}
