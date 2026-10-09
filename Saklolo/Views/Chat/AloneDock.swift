import SwiftUI

/// Alone mode's dock at the bottom of the chat (G1). Nothing is sent at
/// understanding in alone mode; the alert goes when the person says so.
///
/// "I need help" is a countdown bar: it fires on its own when it runs out
/// (`AloneModePolicy.countdown`), or at once when tapped (G2). "I'm okay" is a
/// slide that cancels it before it goes (G5); a slide, not a button, so a
/// stray touch cannot.
struct AloneDock: View {
    /// Send the alert now.
    var onFire: () -> Void
    /// The person is okay: end without sending (G5).
    var onOkay: () -> Void = {}

    @State private var countdown = AloneCountdown(clock: ContinuousClock())

    var body: some View {
        VStack(spacing: Metrics.gap) {
            HelpCountdownBar(countdown: countdown)
            OkaySlide {
                // Only counts if the alert has not gone yet.
                if countdown.okay() { onOkay() }
            }
        }
        .padding(Metrics.gutter)
        .onAppear { countdown.start { onFire() } }
        .onDisappear { countdown.stop() }
    }
}

/// "I need help · sending in 0:10 · tap to send now", with a red bar that
/// empties as the countdown runs.
private struct HelpCountdownBar: View {
    let countdown: AloneCountdown<ContinuousClock>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            countdown.fireNow()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Palette.alarmText.opacity(0.18))
                        Rectangle()
                            .fill(Palette.alarmText)
                            .frame(width: proxy.size.width * countdown.fractionLeft)
                    }
                }
                .frame(height: 8)
                .animation(reduceMotion ? nil : .linear(duration: 1), value: countdown.remaining)

                Text("I need help · sending in \(AloneModePolicy.clockText(countdown.remaining)) · tap to send now")
                    .font(.title3.bold())
                    .foregroundStyle(Palette.alarmText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            .frame(minHeight: Metrics.primaryActionHeight)
            .background(Palette.groundRaised)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                    .strokeBorder(Palette.alarmText, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("I need help")
        .accessibilityValue("Sending in \(Self.spoken(countdown.remaining))")
        .accessibilityHint("Sends the alert text to your contacts now.")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private static func spoken(_ remaining: Duration) -> String {
        let seconds = Int(remaining.components.seconds)
        return seconds == 1 ? "1 second" : "\(seconds) seconds"
    }
}

/// "Slide: I'm okay". The knob must travel most of the track
/// (`AloneModePolicy.slideThreshold`) or it springs back.
private struct OkaySlide: View {
    var onComplete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var done = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let knob: CGFloat = Metrics.primaryActionHeight - 8

    var body: some View {
        GeometryReader { proxy in
            let travel = max(proxy.size.width - knob - 8, 0)
            ZStack(alignment: .leading) {
                Capsule().fill(done ? Palette.delivered.opacity(0.15) : Palette.groundRaised)
                Capsule().strokeBorder(done ? Palette.delivered : Palette.text, lineWidth: 2)

                Text(done ? "I'm okay" : "Slide: I'm okay")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.leading, knob)
                    .opacity(done ? 1 : 1 - Double(offset / max(travel, 1)) * 0.8)

                Circle()
                    .fill(Palette.delivered)
                    .overlay(
                        Image(systemName: done ? "checkmark" : "play.fill")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    )
                    .frame(width: knob, height: knob)
                    .padding(4)
                    .offset(x: done ? travel : offset)
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { value in
                                guard !done else { return }
                                let fraction = AloneModePolicy.slideFraction(translation: value.translation.width, travel: travel)
                                offset = CGFloat(fraction) * travel
                            }
                            .onEnded { value in
                                guard !done else { return }
                                let fraction = AloneModePolicy.slideFraction(translation: value.translation.width, travel: travel)
                                if AloneModePolicy.slideCompletes(fraction: fraction) {
                                    complete()
                                } else {
                                    withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) { offset = 0 }
                                }
                            }
                    )
            }
        }
        .frame(height: Metrics.primaryActionHeight)
        // VoiceOver and Switch Control cannot drag; the named action is
        // their deliberate equivalent of the full slide.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(done ? "I'm okay" : "Slide: I'm okay")
        .accessibilityHint("Stops the alert. Nothing is sent to your contacts.")
        .accessibilityAction(named: "I'm okay") { complete() }
    }

    private func complete() {
        guard !done else { return }
        done = true
        onComplete()
    }
}

#Preview {
    VStack {
        Spacer()
        AloneDock(onFire: { print("fire") }, onOkay: { print("okay") })
    }
    .saklaloGround()
}
