import SwiftUI

/// The voice orb at the bottom of the chat (F1, F2). The mark's rings swell
/// with the voice. Calm: they move with the level, never flash.
struct VoiceOrb: View {
    enum Phase: Equatable {
        /// Recording, nothing loud enough heard yet.
        case waiting
        /// Recording, voice picked up.
        case hearing
        /// Recording done, Whisper is working. The orb shrinks (F2).
        case transcribing
    }

    /// Where the alert is, once it has started going out while the orb is
    /// still listening. The orb then says so instead of asking the person
    /// to speak louder: the alert does not depend on being heard any more.
    enum AlertState: Equatable {
        /// Handed to the Shortcut or held for signal; not confirmed yet.
        case sending
        /// Confirmed sent (Shortcut x-success, or the composer).
        case sent
        /// Not sent; the card above has the composer button.
        case needsPerson

        /// The state for a queue entry's status; `.sending` before the
        /// alert has reached the queue.
        init(_ status: AlertQueue.Entry.Status?) {
            switch status {
            case .sent?: self = .sent
            case .needsComposer?: self = .needsPerson
            case .confirming?, .waiting?, nil: self = .sending
            }
        }
    }

    var phase: Phase
    /// Mic level, 0...1.
    var level: Float
    /// nil until the alert starts going out.
    var alert: AlertState? = nil

    @State private var quietTooLong = false

    /// The mockup's `.bw.o`: a 92pt red core with the mic, three 4pt rings
    /// 10, 20 and 30pt outside it. Transcribing shrinks the core to 56pt (F2).
    private static let coreSize: CGFloat = 92
    private static let transcribingCoreSize: CGFloat = 56
    private static let rings: [(color: Color, inset: CGFloat, opacity: Double)] = [
        (Palette.signalOrange, 10, 0.85),
        (Palette.signalYellow, 20, 0.75),
        (Palette.signalBlue, 30, 0.7),
    ]
    /// Room for the outer ring at its loudest.
    private static let frameSize: CGFloat = 170

    private var scale: CGFloat { phase == .transcribing ? Self.transcribingCoreSize / Self.coreSize : 1 }

    var body: some View {
        VStack(spacing: 16) {
            Text(statusText)
                .font(Typography.body) // 17pt at the default size, scales with Dynamic Type
                .foregroundStyle(showsQuietWarning ? Palette.alarmText : Palette.textDim)
                .multilineTextAlignment(.center)
                .accessibilityLabel(statusText)

            ZStack {
                ForEach(Array(Self.rings.enumerated()), id: \.offset) { index, ring in
                    Circle()
                        .strokeBorder(ring.color.opacity(ring.opacity), lineWidth: 4)
                        .frame(width: Self.coreSize + ring.inset * 2, height: Self.coreSize + ring.inset * 2)
                        .scaleEffect(1 + CGFloat(level) * 0.08 * CGFloat(index + 1))
                }
                Circle()
                    .fill(Palette.signalRed)
                    .frame(width: Self.coreSize, height: Self.coreSize)
                Image(systemName: "mic.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: Self.frameSize, height: Self.frameSize)
            .scaleEffect(scale)
            .frame(height: Self.frameSize * scale)
            .animation(.easeOut(duration: 0.1), value: level)
            .animation(.easeOut(duration: 0.3), value: phase)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, Metrics.gutter)
        .task(id: phase) {
            quietTooLong = false
            guard phase == .waiting else { return }
            try? await Task.sleep(for: .seconds(3))
            quietTooLong = true
        }
    }

    private var statusText: String {
        Self.statusText(phase: phase, quietTooLong: quietTooLong, alert: alert)
    }

    private var showsQuietWarning: Bool {
        Self.statusText(phase: phase, quietTooLong: quietTooLong, alert: alert) == Self.cantHearYou
    }

    static let cantHearYou = "Can't hear you. Speak louder."
    static let listening = "Listening\u{2026}"
    static let understanding = "Understanding\u{2026}"

    /// The line above the orb. Once the alert is going out, "can't hear
    /// you" is never shown: it reads as if help depends on speaking up.
    static func statusText(phase: Phase, quietTooLong: Bool, alert: AlertState?) -> String {
        if phase == .transcribing { return understanding }
        switch alert {
        case .sending?: return "Sending the alert. Keep talking if you can."
        case .sent?: return "Alert sent. Keep talking if you can."
        case .needsPerson?: return "Tap Send message above. Keep talking if you can."
        case nil: break
        }
        switch phase {
        case .waiting: return quietTooLong ? cantHearYou : listening
        case .hearing: return listening
        case .transcribing: return understanding
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        VoiceOrb(phase: .hearing, level: 0.5)
        VoiceOrb(phase: .transcribing, level: 0)
    }
    .saklaloGround()
}
