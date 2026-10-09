import SwiftUI

/// The Saklolo mark (mockup A1): blue outermost ring, then yellow, orange, and a red core.
/// Drawn on a 120-unit grid like the SVG: ring radii 49, 37, 25 with a 7-unit stroke, core radius 13.
/// Decorative: VoiceOver reads the wordmark or the screen's own label instead.
struct SaklaloMark: View {
    var size: CGFloat

    var body: some View {
        let unit = size / 120
        ZStack {
            ring(Palette.signalBlue, radius: 49, unit: unit)
            ring(Palette.signalYellow, radius: 37, unit: unit)
            ring(Palette.signalOrange, radius: 25, unit: unit)
            Circle()
                .fill(Palette.signalRed)
                .frame(width: 26 * unit, height: 26 * unit)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// `stroke` centres the line on the radius, as SVG does.
    private func ring(_ color: Color, radius: CGFloat, unit: CGFloat) -> some View {
        Circle()
            .stroke(color, lineWidth: 7 * unit)
            .frame(width: radius * 2 * unit, height: radius * 2 * unit)
    }
}

/// "SAKLOLO" in Barlow ExtraBold, uppercase, 0.03em tracking (mockup `.wm`).
struct SaklaloWordmark: View {
    var size: CGFloat = 28

    var body: some View {
        Text("Saklolo")
            .font(Typography.signage(size, relativeTo: .title))
            .textCase(.uppercase)
            .tracking(Typography.wordmarkTracking(size))
            .lineLimit(1)
            .fixedSize()
    }
}

#Preview("Mark") {
    VStack(spacing: 10) {
        SaklaloMark(size: 190)
        SaklaloWordmark(size: 64)
        SaklaloWordmark()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .saklaloGround()
}
