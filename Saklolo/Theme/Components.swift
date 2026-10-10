import SwiftUI

// Mockup components (docs/mockup/mockup.html). Pixel sizes from the CSS map to the nearest
// system text style so Dynamic Type keeps working: 12 caption, 13 footnote, 15 subheadline,
// 16 callout, 17 body.

// MARK: - Status pill

/// A short status in a capsule (mockup `.pill`): "Ready", "Microphone off", "Text sent".
struct StatusPill: View {
    enum Tone: Equatable {
        /// Plain information.
        case neutral
        /// Something isn't working: alarm text.
        case fail
        /// Something really happened (sent, delivered): delivered text on its tint.
        case done
    }

    let text: String
    var systemImage: String?
    var tone: Tone

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(_ text: String, systemImage: String? = nil, tone: Tone = .neutral) {
        self.text = text
        self.systemImage = systemImage
        self.tone = tone
    }

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .fontWeight(.bold)
            }
            Text(text)
                // Wraps instead of truncating: two lines at most, as many as it needs at AX sizes.
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(minHeight: 34)
        // A capsule at one line; stays a rounded tile, not a lozenge, when the text wraps.
        .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(background))
        .accessibilityElement(children: .combine)
    }

    private var foreground: Color {
        switch tone {
        case .neutral: Palette.text
        case .fail: Palette.alarmText
        case .done: Palette.delivered
        }
    }

    private var background: Color {
        tone == .done ? Palette.deliveredTint : Palette.groundRaised
    }
}

// MARK: - Readiness line

/// One part of the readiness line: "Mic", "GPS", "3 contacts ready".
struct ReadinessItem: Equatable, Hashable {
    let label: String
    let isOK: Bool
}

/// What the phone can do right now (mockup `.ready`). A missing part is alarm text with a cross,
/// so meaning never rests on color alone.
struct ReadinessLine: View {
    let items: [ReadinessItem]

    var body: some View {
        FlowRow(spacing: 14, lineSpacing: 6) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 5) {
                    Image(systemName: item.isOK ? "checkmark" : "xmark")
                        .imageScale(.small)
                        .fontWeight(.bold)
                    Text(item.label)
                }
                .foregroundStyle(item.isOK ? Palette.textDim : Palette.alarmText)
                .fontWeight(item.isOK ? .regular : .bold)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(item.isOK ? item.label : "\(item.label) off")
            }
        }
        .font(.subheadline)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Palette.groundRaised))
    }
}

/// Lays children out left to right, wrapping to centred lines (CSS `flex-wrap` + `justify-content: center`).
/// Keeps the readiness line readable at the largest text sizes.
private struct FlowRow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = lines(for: subviews, width: proposal.width ?? .infinity)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(lines.count - 1, 0))
        return CGSize(width: proposal.width.map { min($0, width) } ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(for: subviews, width: bounds.width) {
            var x = bounds.minX + (bounds.width - line.width) / 2
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func lines(for subviews: Subviews, width maxWidth: CGFloat) -> [Line] {
        var lines: [Line] = []
        var current = Line()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let added = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty && added > maxWidth {
                lines.append(current)
                current = Line()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { lines.append(current) }
        return lines
    }
}

// MARK: - Notices and banners

/// A one-line notice on a raised tile (mockup `.fb`, `.fb.lk`, `.ib`).
/// Failure carries a 5pt alarm edge on the left; info is dim. The optional action is an underlined link.
struct InlineNotice: View {
    enum Tone: Equatable { case failure, info }

    let text: String
    let systemImage: String
    let tone: Tone
    var actionTitle: String?
    var action: (() -> Void)?

    init(_ text: String, systemImage: String, tone: Tone, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.text = text
        self.systemImage = systemImage
        self.tone = tone
        self.actionTitle = actionTitle
        self.action = action
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var hasAction: Bool { actionTitle != nil && action != nil }
    /// At accessibility sizes the action moves under the text so neither gets squeezed or clipped.
    private var stacksAction: Bool { hasAction && dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Group {
            if stacksAction {
                VStack(alignment: .leading, spacing: 4) {
                    message
                    actionButton
                }
            } else {
                HStack(alignment: hasAction ? .center : .top, spacing: 10) {
                    message
                    actionButton
                }
            }
        }
        .padding(.vertical, hasAction && !stacksAction ? 0 : 12)
        .padding(.horizontal, 14)
        .padding(.leading, tone == .failure ? 5 : 0)
        .frame(minHeight: hasAction ? 46 : nil)
        .background(Palette.groundRaised)
        .overlay(alignment: .leading) {
            if tone == .failure {
                Rectangle().fill(Palette.alarmText).frame(width: 5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var message: some View {
        HStack(alignment: hasAction && !stacksAction ? .center : .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .foregroundStyle(tone == .failure ? Palette.alarmText : Palette.textDim)
                .accessibilityHidden(true)
            Text(text)
                .font(.callout.weight(.medium))
                .foregroundStyle(Palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let actionTitle, let action {
            Button(action: action) {
                Text(actionTitle)
                    .font(.callout.weight(.bold))
                    .underline()
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: Metrics.minTarget)
                    .padding(.leading, stacksAction ? 0 : 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// Only after the alert really went out (mockup `.banner`): delivered text with a check on its tint.
struct DeliveredBanner: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.body.weight(.bold))
                .accessibilityHidden(true)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Palette.delivered)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Palette.deliveredTint))
        .accessibilityElement(children: .combine)
    }
}

/// The exact text that went out (mockup `.sent`). Pass the message body; the box adds "Sent:" and quotes.
struct SentTextBox: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text("Sent: \u{201C}\(text)\u{201D}")
            .font(.caption)
            .foregroundStyle(Palette.textDim)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Palette.groundRaised))
    }
}

// MARK: - Contacts

/// An emergency contact with its priority tile (mockup `.chip`).
/// Tiles 1 to 3 use DESIGN.md's yellow, orange, blue; 4 and 5 are plain (DESIGN.md defines only three).
struct ContactChip: View {
    let position: Int
    let name: String
    var caption: String?
    var relation: String?
    var trailing: AnyView?
    /// The setup list's taller 58pt row; off by default (48pt).
    var tall: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The numeral tile grows with the numeral, capped so it never crowds out the name.
    @ScaledMetric(relativeTo: .title3) private var tileSize: CGFloat = 36

    init(position: Int, name: String, caption: String?, relation: String?, trailing: AnyView? = nil, tall: Bool = false) {
        self.position = position
        self.name = name
        self.caption = caption
        self.relation = relation
        self.trailing = trailing
        self.tall = tall
    }

    var body: some View {
        // At accessibility sizes nothing truncates: the name wraps and the relation moves under it.
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let tile = min(tileSize, 56)
        HStack(spacing: 12) {
            Text("\(position)")
                .font(Typography.signage(24, relativeTo: .title3))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(Self.numeralColor(for: position))
                .frame(width: tile, height: tile)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                        .fill(Self.tileColor(for: position))
                )
                .accessibilityLabel("Contact \(position)")
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.body)
                    .foregroundStyle(Palette.text)
                if let caption {
                    Text(caption)
                        .font(.footnote)
                        .foregroundStyle(Palette.textDim)
                }
                if isLarge, let relation {
                    Text(relation)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textDim)
                }
            }
            .lineLimit(isLarge ? nil : 1)
            .fixedSize(horizontal: false, vertical: isLarge)
            Spacer(minLength: 8)
            if !isLarge, let relation {
                Text(relation)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(1)
            }
            if let trailing {
                trailing
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 8)
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, minHeight: tall ? 58 : 48, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Palette.groundRaised))
        .accessibilityElement(children: .combine)
    }

    static func tileColor(for position: Int) -> Color {
        switch position {
        case 1: Palette.signalYellow
        case 2: Palette.signalOrange
        case 3: Palette.signalBlue
        default: Palette.line
        }
    }

    static func numeralColor(for position: Int) -> Color {
        (1...3).contains(position) ? Palette.ink : Palette.text
    }
}

// MARK: - Fields, cards, progress

private struct SaklaloFieldModifier: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Palette.textDim)
            }
            content
                .font(.body)
                .foregroundStyle(Palette.text)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Palette.groundRaised))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 2)
        )
    }
}

extension View {
    /// A text field or picker in the mockup's field box (`.field`): raised fill, 2pt line border,
    /// a small dim label above the value.
    func saklaloField(label: String?) -> some View {
        modifier(SaklaloFieldModifier(label: label))
    }

    /// Raised sheet background with the mockup's 26pt top corners.
    func saklaloSheet() -> some View {
        presentationBackground(Palette.groundRaised)
            .presentationCornerRadius(Metrics.sheetRadius)
    }
}

/// A raised card with an optional small heading (mockup `.det`).
struct SectionCard<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.textDim)
                    .accessibilityAddTraits(.isHeader)
            }
            content
                .font(.subheadline)
                .foregroundStyle(Palette.text)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Palette.groundRaised))
    }
}

/// A plain progress track (mockup `.prog`; `thick` is `.prog.fat`). `value` is 0...1.
struct SaklaloProgressBar: View {
    var value: Double
    var thick = false

    var body: some View {
        let clamped = min(max(value, 0), 1)
        Capsule()
            .fill(Palette.line)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Palette.text)
                        .frame(width: proxy.size.width * clamped)
                }
            }
            .clipShape(Capsule())
            .frame(height: thick ? 12 : 4)
            .accessibilityElement()
            .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }
}
