import SwiftUI

/// Shown at launch while the on-device speech model downloads (first run),
/// compiles and self-tests. Calm by design (DESIGN.md): the concentric rings
/// fill in the signal order, no flashing. CoreML reports no progress while it
/// compiles, so the screen shows what it can be honest about: which step it
/// is on, how long it has been, and, on a first run, how long it usually
/// takes. The emergency bypass is always on screen, because the alert must
/// never wait on the model.
struct LoadingView: View {
    @ObservedObject var loader: ModelLoader
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spinning = false

    private enum Step: Int, CaseIterable {
        case download, compile, test

        var label: String {
            switch self {
            case .download: "Kunin ang modelo"
            case .compile: "Ihanda sa telepono"
            case .test: "Subukan ang pandinig"
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            rings
                .frame(width: 200, height: 200)

            VStack(spacing: 6) {
                Text("SAKLOLO")
                    .font(Typography.signage(46, relativeTo: .largeTitle))
                    .tracking(1.2)
                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textDim)
            }

            if loader.phase != .failed {
                steps
                timer
            }

            Text(note)
                .font(Typography.finePrint)
                .foregroundStyle(loader.phase == .failed ? Palette.alarmText : Palette.textDim)
                .multilineTextAlignment(.center)
                .frame(minHeight: 50, alignment: .top)

            Spacer(minLength: 0)

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

    // MARK: - Steps and timer

    private var currentStep: Step? {
        switch loader.phase {
        case .downloading: .download
        case .compiling: .compile
        case .testing: .test
        case .ready, .failed: nil
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(visibleSteps, id: \.rawValue) { step in
                HStack(spacing: 12) {
                    stepIcon(step)
                        .frame(width: 24, height: 24)
                    Text(step.label)
                        .font(Typography.body)
                        .foregroundStyle(state(of: step) == .pending ? Palette.textDim : Palette.text)
                    Spacer(minLength: 0)
                    if case .downloading(let value) = loader.phase, step == .download {
                        Text("\(Int(value * 100))%")
                            .font(Typography.body)
                            .monospacedDigit()
                            .foregroundStyle(Palette.textDim)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Palette.groundRaised, in: RoundedRectangle(cornerRadius: Metrics.chipRadius))
        .accessibilityElement(children: .combine)
    }

    /// The download step only shows if a download happened this time.
    private var visibleSteps: [Step] {
        loader.didDownload ? Step.allCases : [.compile, .test]
    }

    private enum StepState { case done, active, pending }

    private func state(of step: Step) -> StepState {
        guard let current = currentStep else { return loader.phase == .ready ? .done : .pending }
        if step.rawValue < current.rawValue { return .done }
        return step == current ? .active : .pending
    }

    @ViewBuilder
    private func stepIcon(_ step: Step) -> some View {
        switch state(of: step) {
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.delivered)
        case .active:
            Image(systemName: "circle.dotted")
                .foregroundStyle(Palette.signalBlue)
                .rotationEffect(spinning ? .degrees(360) : .zero)
                .animation(reduceMotion ? nil : .linear(duration: 3).repeatForever(autoreverses: false), value: spinning)
                .onAppear { spinning = true }
        case .pending:
            Image(systemName: "circle").foregroundStyle(Palette.line)
        }
    }

    /// Ticks once a second so a long compile visibly moves.
    private var timer: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = max(0, Int(context.date.timeIntervalSince(loader.startedAt)))
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                .font(Typography.signage(28, relativeTo: .title2))
                .monospacedDigit()
                .foregroundStyle(Palette.textDim)
                .accessibilityLabel("\(seconds) seconds elapsed")
        }
    }

    // MARK: - Copy

    private var title: String {
        switch loader.phase {
        case .downloading: "Kinukuha ang pandinig"
        case .compiling: "Inihahanda ang pandinig"
        case .testing: "Sinusubukan ang pandinig"
        case .ready: "Handa na"
        case .failed: "Hindi pa handa ang pandinig"
        }
    }

    private var note: String {
        switch loader.phase {
        case .downloading:
            return "Isang beses lang ito at kailangan ng internet. Pagkatapos, gagana na kahit offline."
        case .compiling where loader.isFirstRun:
            return "Unang beses ito. Karaniwang 3 hanggang 4 na minuto. Huwag isara ang app at panatilihing bukas ang screen."
        case .compiling, .testing:
            return "Sandali lang."
        case .ready:
            return ""
        case .failed:
            return "Walang internet o hindi ma-load. Gagana pa rin ang alerto at gabay, pero hindi ka mapapakinggan."
        }
    }

    // MARK: - Rings

    /// Overall progress for the rings. Download is the first third; the
    /// unknown-length compile gets a spinner arc instead of a fake number.
    private var fraction: Double? {
        switch loader.phase {
        case .downloading(let value): value / 3
        case .compiling: 1.0 / 3
        case .testing: 2.0 / 3
        case .ready: 1
        case .failed: nil
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
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: progress)
        .accessibilityElement()
        .accessibilityLabel(title)
    }

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

#Preview("Compiling") {
    LoadingView(loader: ModelLoader(), onContinue: {})
}
