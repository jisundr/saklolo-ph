import SwiftUI

/// A failure as a card in the chat, never a pop-up, so the guide sheet stays
/// in view (I1 to I4). Reads the latest alert from `AlertQueue`, so a card
/// turns into "I've told ..." only once the Shortcut confirms the text went
/// out (or the composer sends it).
struct FallbackCardView: View {
    let kind: FallbackKind
    @ObservedObject var queue: AlertQueue = .shared

    private var entry: AlertQueue.Entry? { queue.latest }

    var body: some View {
        Group {
            switch kind {
            case .sending:
                switch entry?.status {
                case .needsComposer?: sendCard
                case .sent(let at)?: delivered(at: at)
                default: sendingCard
                }
            case .sendFailed:
                sendCard
            case .composer:
                composerButton
            case .noSignal:
                if entry?.status == .needsComposer {
                    sendCard
                } else {
                    noSignalCard
                }
            case .noLocation:
                locationChips
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Handed to the Shortcut, not confirmed yet

    private var sendingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProgressView()
                Text(entry?.outcome.sendingLine ?? "Sending the alert\u{2026}")
                    .font(Typography.body.weight(.semibold))
            }
            if let quoted = entry?.outcome.quotedMessage {
                Text(quoted)
                    .font(Typography.finePrint)
                    .foregroundStyle(Palette.textDim)
            }
        }
        .foregroundStyle(Palette.text)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                .strokeBorder(Palette.textDim, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - I1, I2: the Shortcut could not send it

    @ViewBuilder
    private var sendCard: some View {
        if let sent = sentAt {
            delivered(at: sent)
        } else {
            VStack(alignment: .leading, spacing: Metrics.gap) {
                warning("I couldn't send the text by myself. Tap to send it to \(recipients).")
                composerButton
            }
        }
    }

    @ViewBuilder
    private var composerButton: some View {
        if let entry, sentAt == nil {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    MessageComposer.present(
                        recipients: entry.outcome.recipientPhones,
                        body: entry.outcome.message
                    ) { [queue] in
                        queue.composerSent(entry.id)
                    }
                } label: {
                    Text("Send message")
                        .font(.body.bold())
                        .foregroundStyle(Palette.onAction)
                        .frame(maxWidth: .infinity, minHeight: Metrics.minTarget + 8)
                        .background(
                            RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                                .fill(Palette.action)
                        )
                }
                .disabled(!MessageComposer.canSendText)
                .accessibilityHint("Opens a message to your contacts with the alert text. Tap Send.")
                if !MessageComposer.canSendText {
                    Text("This phone cannot send texts.")
                        .font(Typography.finePrint)
                        .foregroundStyle(Palette.textDim)
                }
            }
        }
    }

    // MARK: - I3: no signal

    @ViewBuilder
    private var noSignalCard: some View {
        if let sent = sentAt {
            delivered(at: sent)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                warning("No signal. I'll keep trying and send the text as soon as there is signal.")
                HStack(spacing: 8) {
                    chip("Text queued", done: false)
                    chip("Retrying every \(retrySeconds) s", done: false)
                }
            }
        }
    }

    private var retrySeconds: Int64 { AlertPolicy.retryInterval.components.seconds }

    // MARK: - I4: no live location

    @ViewBuilder
    private var locationChips: some View {
        if let text = entry?.outcome.locationChipText {
            let hasFix = entry?.outcome.location != nil
            Label(text, systemImage: hasFix ? "mappin.and.ellipse" : "location.slash")
                .font(Typography.finePrint.weight(.semibold))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().strokeBorder(Palette.signalOrange, lineWidth: 1))
        }
    }

    // MARK: - Parts

    private var sentAt: Date? {
        if case .sent(let at)? = entry?.status { at } else { nil }
    }

    private var recipients: String {
        entry?.outcome.recipientList ?? "your contacts"
    }

    private func delivered(at time: Date) -> some View {
        let line = entry?.outcome.toldLine ?? "I've sent the alert"
        let quoted = entry.map { "\n\($0.outcome.quotedMessage)" } ?? ""
        return Text("\u{2713} \(line) \u{00B7} \(time.formatted(date: .omitted, time: .shortened))\(quoted)")
            .font(Typography.body.weight(.semibold))
            .foregroundStyle(Palette.delivered)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                    .strokeBorder(Palette.delivered, lineWidth: 1.5)
            )
    }

    private func warning(_ text: String) -> some View {
        Text(text)
            .font(Typography.body.weight(.semibold))
            .foregroundStyle(Palette.text)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                    .fill(Palette.signalOrange.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                    .strokeBorder(Palette.signalOrange, lineWidth: 1.5)
            )
    }

    /// Meaning is never color alone: a check for done, an open circle for
    /// still waiting.
    private func chip(_ text: String, done: Bool) -> some View {
        Label(text, systemImage: done ? "checkmark" : "circle")
            .font(Typography.finePrint.weight(.semibold))
            .foregroundStyle(done ? Palette.delivered : Palette.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().strokeBorder(done ? Palette.delivered : Palette.signalOrange, lineWidth: 1)
            )
    }
}

#Preview {
    VStack(spacing: 10) {
        FallbackCardView(kind: .sending)
        FallbackCardView(kind: .sendFailed)
        FallbackCardView(kind: .noSignal)
        FallbackCardView(kind: .noLocation)
    }
    .padding()
    .saklaloGround()
}
