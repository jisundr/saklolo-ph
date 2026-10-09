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

    private var size: CGFloat { phase == .transcribing ? 0.6 : 1 }

    var body: some View {
        VStack(spacing: 10) {
            Text(statusText)
                .font(Typography.body)
                .foregroundStyle(showsQuietWarning ? Palette.alarmText : Palette.textDim)
                .accessibilityLabel(statusText)

            ZStack {
                Circle().fill(Palette.signalRed.opacity(0.9)).frame(width: 56, height: 56)
                ForEach(Array([Palette.signalOrange, Palette.signalYellow, Palette.signalBlue].enumerated()), id: \.offset) { index, color in
                    Circle()
                        .strokeBorder(color.opacity(phase == .hearing ? 0.9 : 0.35), lineWidth: 5)
                        .frame(width: 56 + CGFloat(index + 1) * 26, height: 56 + CGFloat(index + 1) * 26)
                        .scaleEffect(1 + CGFloat(level) * 0.12 * CGFloat(index + 1))
                }
            }
            .frame(width: 200, height: 200)
            .scaleEffect(size)
            .frame(height: 200 * size)
            .animation(.easeOut(duration: 0.1), value: level)
            .animation(.easeOut(duration: 0.3), value: phase)
            .accessibilityHidden(true)
        }
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

    /// The line above the orb. Once the alert is going out, "can't hear
    /// you" is never shown: it reads as if help depends on speaking up.
    static func statusText(phase: Phase, quietTooLong: Bool, alert: AlertState?) -> String {
        if phase == .transcribing { return "Understanding..." }
        switch alert {
        case .sending?: return "Sending the alert. Keep talking if you can."
        case .sent?: return "Alert sent. Keep talking if you can."
        case .needsPerson?: return "Tap Send message above. Keep talking if you can."
        case nil: break
        }
        switch phase {
        case .waiting: return quietTooLong ? cantHearYou : "Listening..."
        case .hearing: return "I can hear you. Keep talking."
        case .transcribing: return "Understanding..."
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
