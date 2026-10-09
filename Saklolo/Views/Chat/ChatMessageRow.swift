import SwiftUI

/// One entry in the chat thread: the person's words on the right, Saklolo's
/// fixed replies on the left, the alert as a delivered card (F2, F3).
struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        switch message.kind {
        case .text(let text):
            bubble(text)
        case .alert(let text):
            alertCard(text)
        case .fallback:
            // Fallback cards are drawn by the fallback work (T7).
            EmptyView()
        }
    }

    private func bubble(_ text: String) -> some View {
        let isUser = message.role == .user
        return HStack {
            if isUser { Spacer(minLength: 48) }
            Text(text)
                .font(Typography.body)
                .foregroundStyle(isUser ? Palette.ink : Palette.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                        .fill(isUser ? Palette.signalBlue : Palette.groundRaised)
                )
            if !isUser { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUser ? "You said: \(text)" : "Saklolo: \(text)")
    }

    private func alertCard(_ text: String) -> some View {
        Text(text)
            .font(Typography.body.weight(.semibold))
            .foregroundStyle(Palette.delivered)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                    .strokeBorder(Palette.delivered, lineWidth: 1.5)
            )
    }
}

/// Holds the place of the person's bubble while Whisper works (F2): words
/// cannot appear while they are still speaking.
struct TypingBubble: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack {
            Spacer(minLength: 48)
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Palette.ink)
                        .frame(width: 8, height: 8)
                        .opacity(pulse ? 1 : 0.35)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2),
                            value: pulse
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                    .fill(Palette.signalBlue)
            )
        }
        .onAppear { pulse = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Understanding what you said")
    }
}

#Preview {
    VStack(spacing: 10) {
        ChatMessageRow(message: .saklolo("What happened?"))
        ChatMessageRow(message: .user("Help! Papa fell, his head is bleeding."))
        TypingBubble()
        ChatMessageRow(message: ChatMessage(role: .saklolo, kind: .alert("I've told Kuya Ben and Tita Lina")))
    }
    .padding()
    .saklaloGround()
}
