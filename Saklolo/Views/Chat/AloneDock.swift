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

/// The red "I need help" bar (G1): a white line on top that empties as the
/// countdown runs, the label in signage type, and "sending in 0:10 · tap to
/// send now" under it.
private struct HelpCountdownBar: View {
    let countdown: AloneCountdown<ContinuousClock>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var detailSize: CGFloat = 14

    /// Foreground on the signal red, as on the SAKLOLO button (mockup `--paper-raised`).
    private let onRed = Color.white

    var body: some View {
        Button {
            countdown.fireNow()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(onRed.opacity(0.3))
                        Capsule()
                            .fill(onRed)
                            .frame(width: proxy.size.width * countdown.fractionLeft)
                    }
                }
                .frame(height: 5)
                .animation(reduceMotion ? nil : .linear(duration: 1), value: countdown.remaining)

                Text("I need help")
                    .font(Typography.signage(28, relativeTo: .title2))
                    .tracking(Typography.wordmarkTracking(28))
                    .textCase(.uppercase)

                Text("sending in \(AloneModePolicy.clockText(countdown.remaining)) · tap to send now")
                    .font(.system(size: detailSize))
            }
            .foregroundStyle(onRed)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .frame(minHeight: 72)
            .background(Palette.signalRed)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
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

/// "Slide: I'm okay" (G1, G5). The thumb must travel most of the track
/// (`AloneModePolicy.slideThreshold`) or it springs back. The thumb is the
/// action colour, not green: green means delivered, and nothing was sent.
private struct OkaySlide: View {
    var onComplete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var done = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Mockup `.slide`: 64pt capsule, 2pt border, 3pt padding, 54pt thumb.
    private let border: CGFloat = 2
    private let thumbInset: CGFloat = 5
    private let thumb: CGFloat = Metrics.primaryActionHeight - 2 * 5

    var body: some View {
        GeometryReader { proxy in
            let travel = max(proxy.size.width - thumb - 2 * thumbInset, 0)
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.groundRaised)
                Capsule().strokeBorder(Palette.line, lineWidth: border)

                Text(done ? "I'm okay" : "Slide: I'm okay")
                    .font(Typography.signage(26, relativeTo: .title2))
                    .tracking(Typography.wordmarkTracking(26))
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    // Centred in the part of the track the thumb is not on.
                    .padding(.leading, done ? thumbInset : thumb + thumbInset)
                    .padding(.trailing, done ? thumb + thumbInset : thumbInset)
                    .opacity(done ? 1 : 1 - Double(offset / max(travel, 1)) * 0.8)

                Circle()
                    .fill(Palette.action)
                    .overlay(
                        Image(systemName: done ? "checkmark" : "chevron.right")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Palette.onAction)
                    )
                    .frame(width: thumb, height: thumb)
                    .padding(thumbInset)
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
