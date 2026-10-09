import SwiftUI

/// A failure as a card in the chat, never a pop-up, so the guide sheet stays
/// in view (I1 to I4). Reads the latest alert from `AlertQueue`, so a card
/// turns into "I've told ..." only once the Shortcut confirms the text went
/// out (or the composer sends it).
struct FallbackCardView: View {
    let kind: FallbackKind
    @ObservedObject var queue: AlertQueue = .shared

    private var entry: AlertQueue.Entry? { queue.latest }

    /// What a card shows for its kind and the live state of the alert.
    enum Face: Equatable {
        /// Handed to the Shortcut, not confirmed yet.
        case sending
        /// The text really went out: the delivered banner (F3, I4).
        case delivered(at: Date)
        /// I1: the Shortcut could not send it; the notice and "Send message".
        case couldNotSend
        /// I2 on its own: just "Send message".
        case composer
        /// I3: held for no signal and retried.
        case noSignal
        /// I4: the one location pill.
        case location(LocationPill)
        /// Nothing to show (no alert yet, or the composer already sent it).
        case hidden
    }

    /// I4's pill: what the text said in place of a live location. A
    /// labelled last known fix is plain information (pin); no fix at all is
    /// a failure (cross). Never green: the location is not live.
    struct LocationPill: Equatable {
        let text: String
        let isFailure: Bool

        init(text: String, isFailure: Bool) {
            self.text = text
            self.isFailure = isFailure
        }

        init?(_ outcome: AlertOutcome) {
            guard let text = outcome.locationChipText else { return nil }
            self.init(text: text, isFailure: outcome.location == nil)
        }
    }

    static func face(for kind: FallbackKind, entry: AlertQueue.Entry?) -> Face {
        let sentAt: Date? = if case .sent(let at)? = entry?.status { at } else { nil }
        switch kind {
        case .sending:
            if let sentAt { return .delivered(at: sentAt) }
            return entry?.status == .needsComposer ? .couldNotSend : .sending
        case .sendFailed:
            if let sentAt { return .delivered(at: sentAt) }
            return .couldNotSend
        case .composer:
            return entry != nil && sentAt == nil ? .composer : .hidden
        case .noSignal:
            if let sentAt { return .delivered(at: sentAt) }
            return entry?.status == .needsComposer ? .couldNotSend : .noSignal
        case .noLocation:
            return entry.flatMap { LocationPill($0.outcome) }.map(Face.location) ?? .hidden
        }
    }

    var body: some View {
        Group {
            switch Self.face(for: kind, entry: entry) {
            case .sending: sendingCard
            case .delivered(let at): delivered(at: at)
            case .couldNotSend:
                VStack(alignment: .leading, spacing: Metrics.gap) {
                    InlineNotice(
                        "I couldn't send the text by myself. Tap to send it to \(recipients).",
                        systemImage: "xmark",
                        tone: .failure
                    )
                    composerButton
                }
            case .composer: composerButton
            case .noSignal: noSignalCard
            case .location(let pill): locationPill(pill)
            case .hidden: EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Handed to the Shortcut, not confirmed yet

    private var sendingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                ProgressView()
                    .tint(Palette.textDim)
                Text(entry?.outcome.sendingLine ?? "Sending the alert\u{2026}")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let quoted = entry?.outcome.quotedMessage {
                Text(quoted)
                    .font(.caption)
                    .foregroundStyle(Palette.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Palette.groundRaised))
        .accessibilityElement(children: .combine)
    }

    // MARK: - I1, I2: the Shortcut could not send it

    @ViewBuilder
    private var composerButton: some View {
        if let entry {
            VStack(alignment: .leading, spacing: 6) {
                Button("Send message") {
                    MessageComposer.present(
                        recipients: entry.outcome.recipientPhones,
                        body: entry.outcome.message
                    ) { [queue] in
                        queue.composerSent(entry.id)
                    }
                }
                .buttonStyle(SaklaloActionStyle(kind: .primary))
                .disabled(!MessageComposer.canSendText)
                // The action style has no disabled look; without this a dead button looks live.
                .opacity(MessageComposer.canSendText ? 1 : 0.45)
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

    private var noSignalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            InlineNotice(
                "No signal. I'll keep trying and send the text as soon as there is signal.",
                systemImage: "xmark",
                tone: .failure
            )
            HStack(spacing: 8) {
                StatusPill("Text queued", systemImage: "clock")
                StatusPill("Retrying every \(retrySeconds) s", systemImage: "arrow.clockwise")
            }
        }
    }

    private var retrySeconds: Int64 { AlertPolicy.retryInterval.components.seconds }

    // MARK: - I4: no live location

    private func locationPill(_ pill: LocationPill) -> some View {
        StatusPill(
            pill.text,
            systemImage: pill.isFailure ? "xmark" : "mappin",
            tone: pill.isFailure ? .fail : .neutral
        )
    }

    // MARK: - Delivered

    private var recipients: String {
        entry?.outcome.recipientList ?? "your contacts"
    }

    private func delivered(at time: Date) -> some View {
        let line = entry?.outcome.toldLine ?? "I've sent the alert"
        return VStack(alignment: .leading, spacing: 8) {
            DeliveredBanner("\(line) \u{00B7} \(time.formatted(date: .omitted, time: .shortened))")
            if let message = entry?.outcome.message {
                SentTextBox(message)
            }
        }
    }
}

#if DEBUG
/// One queue per state, so the preview shows every card at once.
@MainActor
private enum FallbackPreview {
    struct NoSender: AlertSending {
        func sendText(_ message: String, id: UUID, notOpened: @escaping @MainActor () -> Void) throws {}
        func call(phone: String) throws {}
    }

    final class NoSignal: SignalChecking {
        var hasSignal: Bool { false }
    }

    static func queue(_ delivery: AlertOutcome.Delivery, location: AlertFix? = nil, sent: Bool = false) -> AlertQueue {
        let queue = AlertQueue(sender: NoSender(), signal: NoSignal())
        let outcome = AlertOutcome(
            delivery: delivery,
            isGeneral: false,
            message: "SAKLOLO: Papa fell, his head is bleeding, he is awake. 7:42pm.",
            recipientNames: ["Kuya Ben", "Tita Lina", "Ruel"],
            location: location,
            records: []
        )
        queue.record(outcome)
        if sent { queue.resolve(outcome.id, .sent) }
        return queue
    }
}

#Preview("Fallback cards") {
    ScrollView {
        VStack(spacing: 14) {
            FallbackCardView(kind: .sending, queue: FallbackPreview.queue(.awaitingConfirmation))
            FallbackCardView(kind: .sendFailed, queue: FallbackPreview.queue(.sendFailed))
            FallbackCardView(kind: .noSignal, queue: FallbackPreview.queue(.queued))
            FallbackCardView(kind: .sending, queue: FallbackPreview.queue(.awaitingConfirmation, sent: true))
            FallbackCardView(
                kind: .noLocation,
                queue: FallbackPreview.queue(
                    .awaitingConfirmation,
                    location: AlertFix(lat: 14.65, lng: 121.05, isLastKnown: true, takenAt: .now)
                )
            )
            FallbackCardView(kind: .noLocation, queue: FallbackPreview.queue(.awaitingConfirmation))
        }
        .padding()
    }
    .saklaloGround()
}
#endif
