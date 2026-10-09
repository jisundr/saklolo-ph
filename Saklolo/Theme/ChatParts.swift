import SwiftUI

/// A chat bubble (mockup `.bub`). Incoming (Saklolo) sits left on the raised ground,
/// with a thin line on paper; outgoing (the person) sits right on `line`. Never blue.
/// `large` is the mockup's `.xl`, used while listening and in alone mode.
struct ChatBubble: View {
    enum Role: Equatable { case incoming, outgoing }

    let text: String
    let role: Role
    let large: Bool

    @ScaledMetric private var fontSize: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    init(_ text: String, role: Role, large: Bool = false) {
        self.text = text
        self.role = role
        self.large = large
        _fontSize = ScaledMetric(
            wrappedValue: large ? Typography.bubbleLargeSize : Typography.bubbleSize,
            relativeTo: .body
        )
    }

    var body: some View {
        BubbleRow(role: role) {
            Text(text)
                .font(.system(size: fontSize))
                .lineSpacing(fontSize * 0.1)
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
                .bubbleBackground(role: role, colorScheme: colorScheme)
        }
    }
}

/// The outgoing placeholder while speech is being written out: three dim dots.
struct TypingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        BubbleRow(role: .outgoing) {
            TimelineView(.animation(minimumInterval: 0.2, paused: reduceMotion)) { context in
                let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.4) % 3
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Palette.textDim)
                            .frame(width: 9, height: 9)
                            .opacity(reduceMotion || index == tick ? 1 : 0.45)
                    }
                }
                .frame(height: 22)
            }
            .bubbleBackground(role: .outgoing, colorScheme: colorScheme)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Writing what you said")
    }
}

private extension View {
    func bubbleBackground(role: ChatBubble.Role, colorScheme: ColorScheme) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.bubbleRadius, style: .continuous)
        return padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(shape.fill(role == .incoming ? Palette.groundRaised : Palette.line))
            .overlay(
                shape.strokeBorder(Palette.line, lineWidth: role == .incoming && colorScheme == .light ? 1.5 : 0)
            )
    }
}

/// Places one bubble at the leading (incoming) or trailing (outgoing) edge, at most 90% of the row.
private struct BubbleRow<Content: View>: View {
    let role: ChatBubble.Role
    @ViewBuilder var content: Content

    var body: some View {
        MaxWidthFraction(fraction: 0.9, trailing: role == .outgoing) {
            content
        }
    }
}

/// Offers its one child `fraction` of the width and pins it to one edge; takes the full width itself.
private struct MaxWidthFraction: Layout {
    let fraction: CGFloat
    let trailing: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let width = proposal.width ?? .infinity
        let size = child.sizeThatFits(ProposedViewSize(width: width.isFinite ? width * fraction : nil, height: nil))
        return CGSize(width: width.isFinite ? width : size.width, height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        let offer = ProposedViewSize(width: bounds.width * fraction, height: nil)
        let size = child.sizeThatFits(offer)
        let x = trailing ? bounds.maxX - size.width : bounds.minX
        child.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(size))
    }
}
