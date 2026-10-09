import SwiftUI

/// Words for the listening model's state. The alert never waits on the model; this only informs.
enum ModelStateText {
    /// `nil` once the model is ready. `compact` is the setup strip ("Preparing listening… 1:12");
    /// full is Home's pill ("Preparing the listening model · 1:42").
    static func text(for phase: ModelLoader.Phase, elapsed: TimeInterval, compact: Bool) -> String? {
        switch phase {
        case .ready:
            return nil
        case .compiling, .testing:
            let clock = clockText(elapsed)
            return compact ? "Preparing listening\u{2026} \(clock)" : "Preparing the listening model \u{00B7} \(clock)"
        case .downloading(let fraction):
            let percent = "\(Int((min(max(fraction, 0), 1) * 100).rounded(.down)))%"
            return compact ? "Getting listening\u{2026} \(percent)" : "Getting the listening model \u{00B7} \(percent)"
        case .failed:
            return compact ? "Listening isn\u{2019}t ready" : "The listening model isn\u{2019}t ready"
        }
    }

    /// m:ss, so the wait reads like a clock.
    static func clockText(_ elapsed: TimeInterval) -> String {
        let seconds = max(0, Int(elapsed.rounded(.down)))
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}

/// The model state as dim text, ticking each second. Shows nothing once the model is ready.
struct ModelStateLabel: View {
    var compact: Bool

    @EnvironmentObject private var loader: ModelLoader

    var body: some View {
        if loader.phase != .ready {
            TimelineView(.periodic(from: loader.startedAt, by: 1)) { context in
                if let text = ModelStateText.text(
                    for: loader.phase,
                    elapsed: context.date.timeIntervalSince(loader.startedAt),
                    compact: compact
                ) {
                    Text(text)
                        .font(compact ? .subheadline : .callout)
                        .monospacedDigit()
                        .foregroundStyle(loader.phase == .failed ? Palette.alarmText : Palette.textDim)
                }
            }
        }
    }
}
