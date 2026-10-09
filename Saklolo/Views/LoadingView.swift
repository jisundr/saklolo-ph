import SwiftUI

/// Shown at launch while the on-device speech model downloads (first run) or
/// loads. Calm by design (DESIGN.md): the concentric rings fill in the
/// signal order, no flashing. The emergency bypass is always on screen,
/// because the alert must never wait on the model.
struct LoadingView: View {
    @ObservedObject var loader: ModelLoader
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            rings
                .frame(width: 220, height: 220)

            VStack(spacing: 8) {
                Text("SAKLOLO")
                    .font(Typography.signage(46, relativeTo: .largeTitle))
                    .tracking(1.2)
                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textDim)
                Text(detail)
                    .font(Typography.finePrint)
                    .foregroundStyle(Palette.textDim)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 34, alignment: .top)
            }
            .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: Metrics.gap) {
                if loader.phase == .failed {
                    Button("Subukan ulit") { Task { await loader.start() } }
                        .buttonStyle(SaklaloActionStyle())
                }
                Button("May emergency? Tuloy na") { onContinue() }
                    .buttonStyle(SaklaloActionStyle(kind: .secondary))
            }
        }
        .padding(Metrics.gutter)
        .saklaloGround()
        .task { await loader.start() }
        .onChange(of: loader.phase) { _, phase in
            if phase == .ready { onContinue() }
        }
    }

    // MARK: - Progress

    /// 0...1, or nil while the length is unknown (loading from disk).
    private var fraction: Double? {
        switch loader.phase {
        case .downloading(let value): value
        case .ready: 1
        case .loading, .failed: nil
        }
    }

    private var title: String {
        switch loader.phase {
        case .downloading: "Inihahanda ang pandinig"
        case .loading: "Binubuksan ang pandinig"
        case .ready: "Handa na"
        case .failed: "Hindi pa handa ang pandinig"
        }
    }

    private var detail: String {
        switch loader.phase {
        case .downloading(let value):
            "\(Int(value * 100))%. Isang beses lang ito at kailangan ng internet. Pagkatapos, gagana na kahit offline."
        case .loading:
            "Sandali lang."
        case .ready:
            ""
        case .failed:
            "Walang internet o hindi ma-download. Gagana pa rin ang alerto at gabay, pero hindi ka mapapakinggan."
        }
    }

    private var rings: some View {
        let progress = fraction ?? 0
        return ZStack {
            // Outer to inner: orange, yellow, blue. Each fills over a third.
            progressRing(Palette.signalOrange, inset: 0, value: segment(progress, 0))
            progressRing(Palette.signalYellow, inset: 24, value: segment(progress, 1))
            progressRing(Palette.signalBlue, inset: 48, value: segment(progress, 2))
            Circle()
                .fill(Palette.signalRed.opacity(0.9))
                .padding(72)
            if fraction == nil && loader.phase != .failed {
                Circle()
                    .trim(from: 0, to: 0.18)
                    .stroke(Palette.text.opacity(0.55), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(spinning ? .degrees(360) : .zero)
                    .animation(reduceMotion ? nil : .linear(duration: 2.4).repeatForever(autoreverses: false), value: spinning)
                    .onAppear { spinning = true }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: progress)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(fraction.map { "\(Int($0 * 100)) percent" } ?? "")
    }

    @State private var spinning = false

    /// Share of ring `index` (of 3) filled at overall `progress`.
    private func segment(_ progress: Double, _ index: Int) -> Double {
        min(max(progress * 3 - Double(index), 0), 1)
    }

    private func progressRing(_ color: Color, inset: CGFloat, value: Double) -> some View {
        ZStack {
            Circle().strokeBorder(color.opacity(0.18), lineWidth: 8)
            Circle()
                .trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(4)
        }
        .padding(inset)
    }
}

#Preview("Downloading") {
    LoadingView(loader: ModelLoader(), onContinue: {})
}
