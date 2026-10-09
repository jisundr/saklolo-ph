import SwiftUI
import UIKit

// Saklolo visual identity: "Signal" direction. See DESIGN.md and docs/brand/brand-board.html.
// Dark ink is the default feel; light is first-class for sunlight. Signal colors never change.

// MARK: - Color

extension Color {
    /// Resolves per appearance. Dynamic, so Dark Mode and Increased Contrast just work.
    fileprivate init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    fileprivate init(hex: UInt32) {
        self.init(UIColor(hex: hex))
    }

    /// Adaptive tint: a color at a different strength on each ground.
    fileprivate init(light: UInt32, lightAlpha: CGFloat, dark: UInt32, darkAlpha: CGFloat) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    fileprivate convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

enum Palette {
    // Surfaces and text (adaptive)
    static let ground = Color(light: 0xF2F5FA, dark: 0x0A1222)
    static let groundRaised = Color(light: 0xFFFFFF, dark: 0x131F38)
    static let line = Color(light: 0xCBD5E6, dark: 0x2B3B5E)
    static let text = Color(light: 0x0A1222, dark: 0xF4F7FD)
    static let textDim = Color(light: 0x44536F, dark: 0xAEBBD6)

    /// Calm primary action: white on ink, ink on paper. Red is never a calm action.
    static let action = Color(light: 0x0A1222, dark: 0xFFFFFF)
    static let onAction = Color(light: 0xFFFFFF, dark: 0x0A1222)

    // Signal colors (constant in both appearances)
    static let signalRed = Color(hex: 0xD81E2B)
    static let signalOrange = Color(hex: 0xFF8A1F)
    static let signalYellow = Color(hex: 0xFFD21F)
    static let signalBlue = Color(hex: 0x4C9AFF)
    /// Text on any signal color except red.
    static let ink = Color(hex: 0x0A1222)

    /// Red as text or a thin line on the ground (brighter on dark to keep 4.5:1).
    static let alarmText = Color(light: 0xC4121F, dark: 0xFF4B55)
    /// Only after something actually happened: SMS delivered, contact answered.
    static let delivered = Color(light: 0x0B7A50, dark: 0x36D399)
    /// Fill behind delivered text: delivered at 14% on ink, 12% on paper.
    static let deliveredTint = Color(light: 0x0B7A50, lightAlpha: 0.12, dark: 0x36D399, darkAlpha: 0.14)
}

// MARK: - Signal level

/// Urgency as a fixed color, numeral and word. Meaning is never color alone.
enum SignalLevel: Int, CaseIterable, Identifiable {
    case bantay = 1, ingat, mabilis, saklolo

    var id: Int { rawValue }

    var word: String {
        switch self {
        case .bantay: "Bantay"
        case .ingat: "Ingat"
        case .mabilis: "Mabilis"
        case .saklolo: "Saklolo"
        }
    }

    var color: Color {
        switch self {
        case .bantay: Palette.signalBlue
        case .ingat: Palette.signalYellow
        case .mabilis: Palette.signalOrange
        case .saklolo: Palette.signalRed
        }
    }

    /// Foreground on `color`: white on red, ink on the rest (all >= 4.5:1).
    var onColor: Color { self == .saklolo ? .white : Palette.ink }

    /// Maps the classifier's free-form urgency string. Unknown means Ingat, never silent.
    init(urgency: String) {
        switch urgency.lowercased() {
        case "low": self = .bantay
        case "medium": self = .ingat
        case "high": self = .mabilis
        case "critical": self = .saklolo
        default: self = .ingat
        }
    }
}

// MARK: - Type

enum Typography {
    /// Barlow Condensed: signage voice. Wordmark, signal levels, button labels, step numbers.
    static func signage(_ size: CGFloat, weight: SignageWeight = .extraBold, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: style)
    }

    enum SignageWeight {
        case semiBold, bold, extraBold

        var postScriptName: String {
            switch self {
            case .semiBold: "BarlowCondensed-SemiBold"
            case .bold: "BarlowCondensed-Bold"
            case .extraBold: "BarlowCondensed-ExtraBold"
            }
        }
    }

    /// Everything people read stays on SF Pro text styles so Dynamic Type works.
    static let step = Font.system(.largeTitle, design: .default, weight: .bold)
    /// Screen title (the mockup's `.t`): the system title style, bold, so Dynamic Type stays the system's.
    static let title = Font.system(.title, design: .default, weight: .bold)
    /// Chat bubble text sizes. Bubbles scale these with Dynamic Type (see `ChatBubble`).
    static let bubbleSize: CGFloat = 18
    static let bubbleLargeSize: CGFloat = 22
    static let bubble = Font.system(size: bubbleSize)
    /// The mockup's `.xl` bubble: listening and alone mode.
    static let bubbleLarge = Font.system(size: bubbleLargeSize)
    /// The name in signage type. Pair with `.textCase(.uppercase)` and `wordmarkTracking`; `SaklaloWordmark` does both.
    static let wordmark = signage(28, relativeTo: .title)
    /// 0.03em, the mockup's letter spacing for signage.
    static func wordmarkTracking(_ size: CGFloat) -> CGFloat { size * 0.03 }
    static let body = Font.body
    static let finePrint = Font.caption
}

// MARK: - Spacing and shape

enum Metrics {
    static let gutter: CGFloat = 20
    static let gap: CGFloat = 12
    static let minTarget: CGFloat = 44
    /// Primary actions in an emergency are far larger than the HIG minimum.
    static let primaryActionHeight: CGFloat = 64
    static let chipRadius: CGFloat = 14
    static let buttonRadius: CGFloat = 18
    /// Bottom sheets (menu, guide, contact editor).
    static let sheetRadius: CGFloat = 26
    static let bubbleRadius: CGFloat = 18
    /// Secondary rows of actions, the mockup's `.btn.sm`.
    static let smallActionHeight: CGFloat = 48
    /// Fields, cards, notices, banners and contact chips.
    static let tileRadius: CGFloat = 14
}

// MARK: - Components

/// "TAPOS NA", "ULITIN": calm, high-contrast, signage type.
struct SaklaloActionStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    /// `.small` is the mockup's `.btn.sm`: 48pt tall, Barlow 20.
    enum Size { case regular, small }
    var kind: Kind = .primary
    var size: Size = .regular

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.signage(size == .regular ? 28 : 20, relativeTo: size == .regular ? .title2 : .headline))
            .textCase(.uppercase)
            .tracking(0.8)
            .frame(maxWidth: .infinity, minHeight: size == .regular ? Metrics.primaryActionHeight : Metrics.smallActionHeight)
            .foregroundStyle(kind == .primary ? Palette.onAction : Palette.text)
            .background(
                RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                    .fill(kind == .primary ? Palette.action : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: kind == .secondary ? 2 : 0)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Urgency chip: numeral + word on the signal color.
struct SignalChip: View {
    let level: SignalLevel

    var body: some View {
        HStack(spacing: 8) {
            Text("\(level.rawValue)")
                .font(Typography.signage(18, relativeTo: .headline))
                .foregroundStyle(level.color)
                .frame(width: 24, height: 24)
                .background(Circle().fill(level.onColor))
            Text(level.word)
                .font(Typography.signage(20, relativeTo: .headline))
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .frame(minHeight: 34)
        .foregroundStyle(level.onColor)
        .background(Capsule().fill(level.color))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Urgency \(level.rawValue) of 4, \(level.word)")
    }
}

/// Progress through a first-aid script. The current step burns brightest.
struct StepStrand: View {
    let count: Int
    let current: Int // zero-based

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Palette.alarmText : (index < current ? Palette.textDim : Palette.line))
                    .frame(height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

/// The SAKLOLO button. Rings are the mark: they appear on trigger, expand once, then hold.
/// `isDimmed` fades the rings when the phone can't do everything (mockup E2 to E6);
/// the red core stays full strength and the button always works.
struct SaklaloButton: View {
    var isActive = false
    var isDimmed = false
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text("SAKLOLO")
                .font(Typography.signage(46, relativeTo: .largeTitle))
                .tracking(1.2)
                .foregroundStyle(.white)
                .frame(width: 220, height: 220)
                .background(Circle().fill(Palette.signalRed))
                .shadow(color: Palette.signalRed.opacity(0.4), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .background(rings)
        .accessibilityLabel("Saklolo")
        .accessibilityHint("Starts an emergency alert and listens for what happened.")
    }

    private var rings: some View {
        ZStack {
            ring(Palette.signalOrange, inset: 16, opacity: ringOpacity(active: 0.9, resting: 0.55))
            ring(Palette.signalYellow, inset: 34, opacity: ringOpacity(active: 0.8, resting: 0.4))
            ring(Palette.signalBlue, inset: 52, opacity: ringOpacity(active: 0.7, resting: 0.32))
        }
        .frame(width: 220, height: 220)
        .scaleEffect(isActive || reduceMotion ? 1 : 0.94)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.9), value: isActive)
        .allowsHitTesting(false)
    }

    private func ringOpacity(active: Double, resting: Double) -> Double {
        if isDimmed { return 0.3 }
        return isActive ? active : resting
    }

    private func ring(_ color: Color, inset: CGFloat, opacity: Double) -> some View {
        Circle()
            .strokeBorder(color.opacity(opacity), lineWidth: 5)
            .padding(-inset)
    }
}

// MARK: - Backgrounds

extension View {
    /// Full-bleed ground for a screen.
    func saklaloGround() -> some View {
        background(Palette.ground.ignoresSafeArea())
            .foregroundStyle(Palette.text)
    }
}

#Preview("Signal levels") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(SignalLevel.allCases) { SignalChip(level: $0) }
        StepStrand(count: 5, current: 1)
        SaklaloButton(isActive: true) {}.padding(60)
        HStack {
            Button("Ulitin") {}.buttonStyle(SaklaloActionStyle(kind: .secondary))
            Button("Tapos na") {}.buttonStyle(SaklaloActionStyle())
        }
    }
    .padding()
    .saklaloGround()
}
