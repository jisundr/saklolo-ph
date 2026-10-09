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

    var phase: Phase
    /// Mic level, 0...1.
    var level: Float

    @State private var quietTooLong = false

    private var size: CGFloat { phase == .transcribing ? 0.6 : 1 }

    var body: some View {
        VStack(spacing: 10) {
            Text(statusText)
                .font(Typography.body)
                .foregroundStyle(quietTooLong && phase == .waiting ? Palette.alarmText : Palette.textDim)
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
        switch phase {
        case .waiting: quietTooLong ? "Can't hear you. Speak louder." : "Listening..."
        case .hearing: "I can hear you. Keep talking."
        case .transcribing: "Understanding..."
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
